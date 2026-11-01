# Immich ML CPU trial

Enable local Smart Search for the home server's 524-asset sample on 16 GB RAM.
The existing v3.3.5 server, PostgreSQL and Paperless images remain unchanged.

The `immich-machine-learning/` derivative keeps the exact official v3.3.5
application and ONNX runtime. Replace only vulnerable Python packages with
published, hash-verified wheels. No source distributions or package build scripts
run during installation. Preserve the full filesystem scan and Python audit;
block fixable HIGH/CRITICAL findings without advisory ignores. Any unfixed native
findings receive an explicit limited-pilot assessment and review date.

Runtime contract: UID/GID 1000, CPU only, one worker/request and inference thread,
2.75 GiB/one CPU, no public port, read-only root and a preseeded encrypted writable model cache, offline
inference. Pin the official default ViT-B-32__openai ONNX model revision and all
six required file sizes/checksums; fetch models separately before activation.
Images, text and model inputs remain on the home server at inference time.

Verification: `make -C immich-machine-learning build-local test scan`, native amd64
CI, and local ARM64 compatibility tests. Test actual HTTP visual/textual vectors,
invalid requests, no-network startup and inference, inactive-model unloading and
reload, hardening and memory limits. Audit installed dependencies against the
committed runtime inventory. CI publishes only the exact tested image on main
under a unique v3.3.5-r1 run/attempt tag; never latest.

Rollout uses a separate guarded home-server change for settings, backup profile
and rollback. No full-library expansion, face/OCR/duplicate jobs, credentials,
production DB restore or Paperless tuning in this image change.
