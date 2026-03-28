#!/usr/bin/env bash
# Tests for lib/utils.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

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

# --- validate_package_name ---

assert_eq "valid package com.example.app" "0" "$(validate_package_name 'com.example.app' && echo 0 || echo 1)"
assert_eq "valid package com.example.myapp" "0" "$(validate_package_name 'com.example.myapp' && echo 0 || echo 1)"
assert_eq "valid package io.github.user.project" "0" "$(validate_package_name 'io.github.user.project' && echo 0 || echo 1)"
assert_eq "reject empty string" "1" "$(validate_package_name '' && echo 0 || echo 1)"
assert_eq "reject single segment" "1" "$(validate_package_name 'myapp' && echo 0 || echo 1)"
assert_eq "reject two segments" "1" "$(validate_package_name 'com.app' && echo 0 || echo 1)"
assert_eq "reject spaces" "1" "$(validate_package_name 'com.my app.test' && echo 0 || echo 1)"
assert_eq "reject uppercase" "1" "$(validate_package_name 'com.Example.App' && echo 0 || echo 1)"
assert_eq "reject leading dot" "1" "$(validate_package_name '.com.example.app' && echo 0 || echo 1)"
assert_eq "reject trailing dot" "1" "$(validate_package_name 'com.example.app.' && echo 0 || echo 1)"
assert_eq "reject consecutive dots" "1" "$(validate_package_name 'com..example.app' && echo 0 || echo 1)"
assert_eq "reject hyphens" "1" "$(validate_package_name 'com.my-app.test' && echo 0 || echo 1)"

# --- validate_app_name ---

assert_eq "valid app name MyApp" "0" "$(validate_app_name 'MyApp' && echo 0 || echo 1)"
assert_eq "valid app name testapp" "0" "$(validate_app_name 'testapp' && echo 0 || echo 1)"
assert_eq "valid app name App123" "0" "$(validate_app_name 'App123' && echo 0 || echo 1)"
assert_eq "reject empty app name" "1" "$(validate_app_name '' && echo 0 || echo 1)"
assert_eq "reject app name with spaces" "1" "$(validate_app_name 'My App' && echo 0 || echo 1)"
assert_eq "reject app name with special chars" "1" "$(validate_app_name 'my-app' && echo 0 || echo 1)"
assert_eq "reject app name starting with number" "1" "$(validate_app_name '1App' && echo 0 || echo 1)"

# --- validate_min_sdk ---

assert_eq "valid min sdk 21" "0" "$(validate_min_sdk '21' && echo 0 || echo 1)"
assert_eq "valid min sdk 24" "0" "$(validate_min_sdk '24' && echo 0 || echo 1)"
assert_eq "valid min sdk 35" "0" "$(validate_min_sdk '35' && echo 0 || echo 1)"
assert_eq "reject min sdk 20 (too low)" "1" "$(validate_min_sdk '20' && echo 0 || echo 1)"
assert_eq "reject min sdk 36 (too high)" "1" "$(validate_min_sdk '36' && echo 0 || echo 1)"
assert_eq "reject non-numeric sdk" "1" "$(validate_min_sdk 'abc' && echo 0 || echo 1)"
assert_eq "reject empty sdk" "1" "$(validate_min_sdk '' && echo 0 || echo 1)"

# --- ensure_command_exists ---

assert_eq "bash exists" "0" "$(ensure_command_exists 'bash' && echo 0 || echo 1)"
assert_eq "nonexistent command" "1" "$(ensure_command_exists 'nonexistent_command_xyz' && echo 0 || echo 1)"

# --- Results ---

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
echo "All tests passed!"
