#!/bin/sh
set -eu
engine=${CONTAINER_ENGINE:-docker}
image=${IMAGE:-immich-machine-learning:local}
nonce=$(python3 -c 'import secrets; print(secrets.token_hex(12))')
volume=bysam-ml-test-$nonce
container=bysam-ml-test-$nonce
cleanup() {
  if [ "$("$engine" inspect --format '{{index .Config.Labels "io.bysamio.ml-test"}}' "$container" 2>/dev/null)" = "$nonce" ]; then
    "$engine" rm -f "$container" >/dev/null
  fi
  if [ "$("$engine" volume inspect --format '{{index .Labels "io.bysamio.ml-test"}}' "$volume" 2>/dev/null)" = "$nonce" ]; then
    "$engine" volume rm "$volume" >/dev/null
  fi
}
trap cleanup EXIT HUP INT TERM
"$engine" run --rm -i --network none --entrypoint python "$image" -c "$(cat test/inventory.py)" < security/runtime.lock
"$engine" volume create --label io.bysamio.ml-test="$nonce" "$volume" >/dev/null
"$engine" run --rm --network none --user 0:0 --cap-drop ALL --cap-add CHOWN --security-opt no-new-privileges \
  -v "$volume:/cache" --entrypoint python "$image" -c 'import os; os.chown("/cache",1000,1000)'
# The one-off downloader handles only public model weights and exits before the
# offline worker exists. There are no credentials, media binds or published ports.
python3 -c 'import json,pathlib; print(json.dumps(json.loads(pathlib.Path("models.lock.json").read_text()))); print(pathlib.Path("fetch_models.py").read_text().split("if __name__ == ")[0])' | "$engine" run --rm -i --cap-drop ALL --security-opt no-new-privileges --memory 512m --memory-swap 512m --cpus 1 \
  -v "$volume:/cache" --entrypoint python "$image" -c 'import sys,pathlib,json; m=json.loads(sys.stdin.readline()); exec(sys.stdin.read()); fetch(m,pathlib.Path("/cache/clip/ViT-B-32__openai"))'
"$engine" run -d --name "$container" --label io.bysamio.ml-test="$nonce" --network none \
  --cap-drop ALL --security-opt no-new-privileges --read-only --memory 2816m --memory-swap 2816m --cpus 1 --pids-limit 128 \
  --tmpfs /tmp:rw,nosuid,nodev,size=64m,mode=1777 -e HF_HUB_OFFLINE=1 \
  -e MACHINE_LEARNING_MODEL_ARENA=false -v "$volume:/cache" "$image" >/dev/null
"$engine" exec -i "$container" python - < test/limits.py
"$engine" exec -i "$container" python - < test/inference.py
"$engine" inspect "$container" | python3 -B test/container_policy.py
