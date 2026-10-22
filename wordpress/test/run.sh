#!/usr/bin/env bash
# Install WordPress against MariaDB with all capabilities dropped and
# no-new-privileges, then load the installed site through Apache on 8080.
# shellcheck disable=SC2016 # single-quoted PHP snippets: $vars belong to PHP
set -euo pipefail

: "${IMAGE:?Set IMAGE to the WordPress image to verify}"
CONTAINER_ENGINE=${CONTAINER_ENGINE:-docker}
MARIADB_IMAGE=${MARIADB_IMAGE:-docker.io/library/mariadb:11}
PORT=${PORT:-18080}

name="bysamio-wp-test-$$"
url="http://127.0.0.1:$PORT"
title="BySamio Image Test"
# Synthetic, throwaway credentials for an isolated test network only.
db_password="synthetic-test-only"
admin_password="synthetic-test-only-Admin1"

restricted=(--cap-drop ALL --security-opt no-new-privileges:true)

cleanup() {
  status=$?
  if [ "$status" -ne 0 ]; then
    "$CONTAINER_ENGINE" logs "$name-wp" 2>&1 | tail -n 40 >&2 || true
  fi
  "$CONTAINER_ENGINE" rm -f "$name-wp" "$name-db" >/dev/null 2>&1 || true
  "$CONTAINER_ENGINE" network rm "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Trivy cannot see PHP (compiled from source), so enforce the PHP2Shell fix
# (CVE-2026-109618, CVE-2026-109619) per branch here. WordPress media handling
# needs these extensions; ImageMagick and libxml2 carry most of the OS security
# updates, so prove they still load and encode after upgrade.
"$CONTAINER_ENGINE" run --rm --network none --user 1001:1001 "${restricted[@]}" \
  --entrypoint php "$IMAGE" -r '
    $fixed = ["8.2" => "8.2.35", "8.3" => "8.3.36", "8.4" => "8.4.27", "8.5" => "8.5.12"];
    $branch = PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;
    if (isset($fixed[$branch]) ? version_compare(PHP_VERSION, $fixed[$branch], "<") : version_compare($branch, "8.5", "<")) {
      fwrite(STDERR, "FAIL: PHP " . PHP_VERSION . " is vulnerable to PHP2Shell (CVE-2026-109618/109619)\n"); exit(1);
    }
    foreach (["curl", "dom", "exif", "fileinfo", "gd", "imagick", "intl", "mbstring", "mysqli", "openssl", "xml", "zip"] as $ext) {
      if (!extension_loaded($ext)) { fwrite(STDERR, "FAIL: PHP extension $ext is not loaded\n"); exit(1); }
    }
    $image = new Imagick();
    $image->newImage(16, 16, "white");
    $image->setImageFormat("jpeg");
    if (strlen($image->getImageBlob()) === 0) { fwrite(STDERR, "FAIL: Imagick produced an empty JPEG\n"); exit(1); }
    echo "PASS: PHP ", PHP_VERSION, " has the PHP2Shell fix, extensions load and Imagick encodes JPEG\n";'

"$CONTAINER_ENGINE" network create "$name" >/dev/null
"$CONTAINER_ENGINE" run -d --name "$name-db" --network "$name" \
  -e MARIADB_DATABASE=wordpress -e MARIADB_USER=wordpress \
  -e MARIADB_PASSWORD="$db_password" -e MARIADB_RANDOM_ROOT_PASSWORD=1 \
  "$MARIADB_IMAGE" >/dev/null
# Default image user, as the Helm chart runs it.
"$CONTAINER_ENGINE" run -d --name "$name-wp" --network "$name" -p "127.0.0.1:$PORT:8080" \
  "${restricted[@]}" \
  -e WORDPRESS_DB_HOST="$name-db" -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD="$db_password" -e WORDPRESS_DB_NAME=wordpress \
  "$IMAGE" >/dev/null

# The installer answers 500 until MariaDB accepts connections.
code=000
deadline=$((SECONDS + 180))
while [ "$SECONDS" -lt "$deadline" ]; do
  code=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' "$url/wp-admin/install.php" || true)
  if [ "$code" = 200 ]; then break; fi
  sleep 2
done
[ "$code" = 200 ] || { echo "FAIL: installer on port 8080 returned HTTP $code" >&2; exit 1; }
echo "PASS: Apache serves the installer on port 8080 with the database reachable"

curl -fsS --max-time 60 -o /dev/null \
  --data-urlencode "weblog_title=$title" --data-urlencode user_name=admin \
  --data-urlencode "admin_password=$admin_password" --data-urlencode "admin_password2=$admin_password" \
  --data-urlencode admin_email=admin@example.com --data-urlencode blog_public=0 \
  "$url/wp-admin/install.php?step=2"

home=$(curl -fsS --max-time 10 "$url/")
case "$home" in
  *"$title"*) ;;
  *) echo "FAIL: installed front page does not show the site title" >&2; exit 1 ;;
esac
curl -fsS --max-time 10 -o /dev/null "$url/wp-login.php"
version=$("$CONTAINER_ENGINE" exec "$name-wp" php -r 'require "/var/www/html/wp-includes/version.php"; echo $wp_version;')
"$CONTAINER_ENGINE" exec "$name-wp" test -w /var/www/html/wp-content/uploads
echo "PASS: WordPress $version installs, serves its front page and login, and can write uploads"
