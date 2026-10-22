#!/usr/bin/env bash
# Trivy cannot see PHP: the upstream image compiles it from source. Fail when
# php.net has released a newer version on the image's PHP branch. 8.3 receives
# security fixes only, so every new 8.3.x is a security release.
# https://www.php.net/supported-versions.php
set -euo pipefail

version=${1:?Usage: test/php-release.sh <php-version, e.g. 8.3.36>}
branch=${version%.*}
latest=$(curl -fsS --max-time 30 "https://www.php.net/releases/index.php?json&version=$branch" | jq -er .version)

if [ "$(printf '%s\n%s\n' "$version" "$latest" | sort -V | tail -n 1)" != "$version" ]; then
  echo "FAIL: image has PHP $version, php.net released $latest on the $branch branch." >&2
  echo "Rebuild once upstream wordpress:<version>-apache ships it, or bump WORDPRESS_VERSION if that tag is no longer rebuilt." >&2
  exit 1
fi
echo "PASS: PHP $version is the latest $branch release on php.net"
