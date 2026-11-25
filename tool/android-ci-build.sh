#!/usr/bin/env bash
set -euo pipefail

log=$(mktemp)
trap 'rm -f "$log"' EXIT
maven_delays=(30 90)
maven_retries=0
ndk_retries=0

while true; do
  if flutter build apk "$@" 2>&1 | tee "$log"; then
    exit 0
  else
    status=$?
  fi

  if grep -Eiq 'status code 429|429 Too Many Requests' "$log"; then
    reason='Maven returned HTTP 429'
    if (( maven_retries >= ${#maven_delays[@]} )); then
      echo "::error title=Android build dependency download failed::$reason after $maven_retries retries."
      exit "$status"
    fi
    delay=${maven_delays[maven_retries]}
    maven_retries=$((maven_retries + 1))
  elif grep -Eiq 'NDK.*(Error on ZipFile|unknown archive)' "$log"; then
    reason='The Android SDK manager could not unpack the NDK archive'
    if (( ndk_retries >= 1 )); then
      echo "::error title=Android build dependency download failed::$reason after one retry."
      exit "$status"
    fi
    delay=15
    ndk_retries=1
  else
    exit "$status"
  fi

  echo "Android build infrastructure retry: $reason. Retrying in ${delay}s."
  sleep "$delay"
done
