#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE:?Set IMAGE to the Paperless image to verify}"
CONTAINER_ENGINE=${CONTAINER_ENGINE:-docker}
case "${1:-all}" in
  all|packages) ;;
  *) echo 'Usage: IMAGE=<image> CONTAINER_ENGINE=docker|podman ./test/run.sh [all|packages]' >&2; exit 2 ;;
esac

run_isolated() {
  "$CONTAINER_ENGINE" run --rm -i --network none --cap-drop ALL \
    --security-opt no-new-privileges:true --entrypoint /bin/sh "$IMAGE" -s
}

run_isolated <<'SH'
set -eu
. /etc/os-release
[ "$VERSION_CODENAME" = trixie ]
for package in ghostscript libgs10 libgs-common libgs10-common; do
  [ "$(dpkg-query -W -f='${db:Status-Status}' "$package")" = installed ]
  version=$(dpkg-query -W -f='${Version}' "$package")
  if ! dpkg --compare-versions "$version" ge '10.05.1~dfsg-1+deb13u3'; then
    echo "FAIL: $package $version is older than 10.05.1~dfsg-1+deb13u3" >&2
    exit 1
  fi
  echo "PASS: $package $version"
done
for package in curl libcurl4t64 libcurl3t64-gnutls; do
  [ "$(dpkg-query -W -f='${db:Status-Status}' "$package")" = installed ]
  version=$(dpkg-query -W -f='${Version}' "$package")
  if ! dpkg --compare-versions "$version" ge '8.14.1-2+deb13u7'; then
    echo "FAIL: $package $version is older than 8.14.1-2+deb13u7" >&2
    exit 1
  fi
  echo "PASS: $package $version"
done
[ "$(dpkg-query -W -f='${db:Status-Status}' librsvg2-2)" = installed ]
version=$(dpkg-query -W -f='${Version}' librsvg2-2)
if ! dpkg --compare-versions "$version" ge '2.60.0+dfsg-1+deb13u1'; then
  echo "FAIL: librsvg2-2 $version is older than 2.60.0+dfsg-1+deb13u1" >&2
  exit 1
fi
echo "PASS: librsvg2-2 $version"
SH

if [ "${1:-all}" = packages ]; then
  exit 0
fi

entrypoint=$("$CONTAINER_ENGINE" image inspect --format '{{json .Config.Entrypoint}}' "$IMAGE")
[ "$entrypoint" = '["/init"]' ] || { echo "FAIL: expected /init entrypoint, got $entrypoint" >&2; exit 1; }
health=$("$CONTAINER_ENGINE" image inspect --format '{{json .Config.Healthcheck.Test}} {{json .Config.Healthcheck.Interval}} {{json .Config.Healthcheck.Timeout}} {{.Config.Healthcheck.Retries}}' "$IMAGE")
[ "$health" = '["CMD","curl","-fs","-S","-L","--max-time","2","http://localhost:8000"] 30000000000 10000000000 5' ] || {
  echo "FAIL: inherited health check changed: $health" >&2; exit 1;
}
volumes=$("$CONTAINER_ENGINE" image inspect --format '{{json .Config.Volumes}}' "$IMAGE")
for directory in data media consume export; do
  case "$volumes" in
    *"\"/usr/src/paperless/$directory\""*) ;;
    *) echo "FAIL: missing inherited $directory volume" >&2; exit 1 ;;
  esac
done
echo 'PASS: inherited entrypoint, health check and volume paths'

run_isolated <<'SH'
set -eu
[ "$(id -u)" -ne 0 ] || { echo 'FAIL: default user is root' >&2; exit 1; }
for directory in data media consume export; do
  [ -d "/usr/src/paperless/$directory" ]
  [ -w "/usr/src/paperless/$directory" ]
done
echo "PASS: default UID $(id -u) can write inherited data paths"
uv pip check --system
python3 - <<'PY'
import os
import importlib.util
import subprocess
import tempfile
from pathlib import Path

assert importlib.util.find_spec("pip") is None, "unused vulnerable pip remains"
assert not list(Path("/usr/local/lib/python3.14/ensurepip/_bundled").glob("pip-*.whl")), "pip bootstrap wheel remains"
from importlib.metadata import version
assert version("fsspec") == "2026.6.0", version("fsspec")

status = dict(line.split(":", 1) for line in Path("/proc/self/status").read_text().splitlines() if ":" in line)
assert int(status["CapEff"].strip(), 16) == 0, "effective capabilities remain"
assert status["NoNewPrivs"].strip() == "1", "privilege escalation is enabled"
languages = subprocess.check_output(["tesseract", "--list-langs"], text=True).splitlines()
assert {"deu", "eng"}.issubset(languages), languages

with tempfile.TemporaryDirectory(prefix="paperless-image-test-") as synthetic:
    root = Path(synthetic)
    for env, name in (("PAPERLESS_DATA_DIR", "data"), ("PAPERLESS_MEDIA_ROOT", "media"),
                      ("PAPERLESS_CONSUMPTION_DIR", "consume"), ("PAPERLESS_SCRATCH_DIR", "scratch")):
        path = root / name
        path.mkdir()
        os.environ[env] = str(path)
    os.environ.update(
        DJANGO_SETTINGS_MODULE="paperless.settings",
        PAPERLESS_SECRET_KEY="synthetic-image-test-only",
        PAPERLESS_OCR_LANGUAGE="deu+eng",
        PAPERLESS_OCR_OUTPUT_TYPE="pdfa",
        PAPERLESS_THREADS_PER_WORKER="1",
        PAPERLESS_CACHE_BACKEND="django.core.cache.backends.locmem.LocMemCache",
    )
    import django
    import pikepdf
    from PIL import Image, ImageDraw, ImageFont
    from django.core.management import call_command

    django.setup()
    call_command("check")
    call_command("migrate", interactive=False, verbosity=0)
    print("PASS: application imports, system checks and isolated SQLite migrations", flush=True)

    # Exercise the upstream parser on pixels, so an existing PDF text layer cannot bypass OCR.
    # https://github.com/paperless-ngx/paperless-ngx/blob/v3.3.0/src/paperless/parsers/tesseract.py
    from paperless.parsers.tesseract import RasterisedDocumentParser

    image = Image.new("RGB", (1600, 600), "white")
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf", 56)
    draw.text((90, 100), "DEUTSCHE RECHNUNG 12345", font=font, fill="black")
    draw.text((90, 220), "ENGLISH INVOICE 67890", font=font, fill="black")
    raster = root / "synthetic.png"
    image.save(raster, dpi=(300, 300))
    with RasterisedDocumentParser() as parser:
        parser.parse(raster, "image/png")
        text = parser.get_text().upper()
        assert "DEUTSCHE RECHNUNG 12345" in text, text
        assert "ENGLISH INVOICE 67890" in text, text
        archive = parser.get_archive_path()
        assert archive and archive.is_file(), "no archive PDF produced"
        with pikepdf.open(archive) as pdf:
            assert len(pdf.pages) == 1
            with pdf.open_metadata() as metadata:
                assert str(metadata["pdfaid:part"]) == "2", metadata
                assert str(metadata["pdfaid:conformance"]) == "B", metadata
        archived_text = subprocess.check_output(["pdftotext", str(archive), "-"], text=True).upper()
        assert "DEUTSCHE RECHNUNG 12345" in archived_text, archived_text
        assert "ENGLISH INVOICE 67890" in archived_text, archived_text
    print("PASS: German/English OCR and searchable PDF/A under restricted privileges", flush=True)

PY
SH

bash "$(dirname "$0")/init.sh"
