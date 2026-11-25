#!/usr/bin/env bash
set -euo pipefail

log=$(mktemp)
trap 'rm -f "$log"' EXIT

for attempt in 1 2; do
  if flutter build apk "$@" 2>&1 | tee "$log"; then
    exit 0
  else
    status=$?
  fi

  if grep -Eiq 'status code 429|429 Too Many Requests' "$log"; then
    reason='Maven returned HTTP 429'
  elif grep -Eiq 'NDK.*(Error on ZipFile|unknown archive)' "$log"; then
    reason='The Android SDK manager could not unpack the NDK archive'
  else
    exit "$status"
  fi

  if [[ "$attempt" == 2 ]]; then
    echo "::error title=Android build dependency download failed::$reason after one retry."
    exit "$status"
  fi

  echo "Android build infrastructure retry: $reason. Retrying once in 15 seconds."
  sleep 15
done
