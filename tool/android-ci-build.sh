#!/usr/bin/env bash
set -euo pipefail

log=$(mktemp)
trap 'rm -f "$log"' EXIT
if flutter build apk "$@" 2>&1 | tee "$log"; then
  exit 0
else
  status=$?
fi

if grep -Eiq 'status code 429|429 Too Many Requests' "$log"; then
  echo '::error title=Android dependency download rate limit::Maven returned HTTP 429. Retry the failed build job.'
elif grep -Eiq 'NDK.*(Error on ZipFile|unknown archive)' "$log"; then
  echo '::error title=Android SDK download failed::The Android SDK manager could not unpack the NDK archive. Retry the failed build job.'
fi
exit "$status"
