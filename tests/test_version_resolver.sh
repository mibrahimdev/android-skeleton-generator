#!/usr/bin/env bash
# Tests for lib/versions.sh

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"
source "$SCRIPT_DIR/../lib/versions.sh"

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    ((PASS++))
  else
    ((FAIL++))
    echo "FAIL: $desc — expected '$expected', got '$actual'"
  fi
}

# --- Test filter_stable_version ---

assert_eq "filter stable from list" "1.7.0" \
  "$(filter_stable_version '1.6.0,1.7.0-alpha01,1.7.0-beta02,1.7.0-rc01,1.7.0')"

assert_eq "filter rejects all unstable" "" \
  "$(filter_stable_version '1.0.0-alpha01,1.0.0-beta01,1.0.0-rc01,1.0.0-dev01')"

assert_eq "filter picks latest stable" "2.0.1" \
  "$(filter_stable_version '1.9.0,2.0.0,2.0.1,2.1.0-alpha01')"

assert_eq "filter single stable" "1.0.0" \
  "$(filter_stable_version '1.0.0')"

assert_eq "filter empty input" "" \
  "$(filter_stable_version '')"

# --- Test parse_google_maven_xml ---

MOCK_XML='<?xml version="1.0" encoding="UTF-8"?>
<androidx.compose.ui>
  <ui-tooling versions="1.5.0-alpha01,1.5.0-beta02,1.5.0,1.6.0-alpha01,1.6.0"/>
  <ui versions="1.5.0,1.6.0-alpha01,1.6.0"/>
</androidx.compose.ui>'

assert_eq "parse google maven xml for ui" "1.6.0" \
  "$(parse_google_maven_xml "$MOCK_XML" "ui")"

assert_eq "parse google maven xml for ui-tooling" "1.6.0" \
  "$(parse_google_maven_xml "$MOCK_XML" "ui-tooling")"

assert_eq "parse google maven xml missing artifact" "" \
  "$(parse_google_maven_xml "$MOCK_XML" "nonexistent")"

# --- Test parse_maven_central_json ---

MOCK_JSON='{
  "response": {
    "docs": [
      {"v": "2.52.1-alpha"},
      {"v": "2.52"},
      {"v": "2.51.1"},
      {"v": "2.51"}
    ]
  }
}'

assert_eq "parse maven central json" "2.52" \
  "$(parse_maven_central_json "$MOCK_JSON")"

MOCK_JSON_ALL_UNSTABLE='{
  "response": {
    "docs": [
      {"v": "1.0.0-alpha"},
      {"v": "1.0.0-beta"}
    ]
  }
}'

assert_eq "parse maven central json all unstable" "" \
  "$(parse_maven_central_json "$MOCK_JSON_ALL_UNSTABLE")"

# --- Test fallback versions exist ---

assert_eq "fallback compose-bom exists" "true" \
  "$([[ -n "$(get_fallback 'compose-bom')" ]] && echo true || echo false)"

assert_eq "fallback hilt exists" "true" \
  "$([[ -n "$(get_fallback 'hilt')" ]] && echo true || echo false)"

assert_eq "fallback retrofit exists" "true" \
  "$([[ -n "$(get_fallback 'retrofit')" ]] && echo true || echo false)"

assert_eq "fallback room exists" "true" \
  "$([[ -n "$(get_fallback 'room')" ]] && echo true || echo false)"

assert_eq "fallback ktor exists" "true" \
  "$([[ -n "$(get_fallback 'ktor')" ]] && echo true || echo false)"

assert_eq "fallback koin exists" "true" \
  "$([[ -n "$(get_fallback 'koin')" ]] && echo true || echo false)"

assert_eq "fallback mockito exists" "true" \
  "$([[ -n "$(get_fallback 'mockito')" ]] && echo true || echo false)"

assert_eq "fallback mockito-kotlin exists" "true" \
  "$([[ -n "$(get_fallback 'mockito-kotlin')" ]] && echo true || echo false)"

# --- Test get_coord ---

assert_eq "coord for hilt" "central:com.google.dagger:hilt-android" \
  "$(get_coord 'hilt')"

assert_eq "coord for room" "google:androidx.room:room-runtime" \
  "$(get_coord 'room')"

# --- Results ---

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
echo "All tests passed!"
