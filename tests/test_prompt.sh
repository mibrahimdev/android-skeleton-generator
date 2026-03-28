#!/usr/bin/env bash
# Tests for lib/prompt.sh (non-interactive mode)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"
source "$SCRIPT_DIR/../lib/prompt.sh"

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

# --- Test parse_args sets variables correctly ---

reset_config() {
  APP_NAME="" PACKAGE_NAME="" MIN_SDK="" ARCH_TYPE="" DI_FRAMEWORK=""
  NETWORK_LIB="" MODULE_TYPE="" OUTPUT_DIR="" NON_INTERACTIVE=""
}

reset_config
parse_args --non-interactive --name TestApp --package com.test.myapp \
  --arch mvvm-clean --di hilt --net retrofit --min-sdk 24 --modules single --output /tmp/test

assert_eq "parse app name" "TestApp" "$APP_NAME"
assert_eq "parse package" "com.test.myapp" "$PACKAGE_NAME"
assert_eq "parse min sdk" "24" "$MIN_SDK"
assert_eq "parse arch" "mvvm-clean" "$ARCH_TYPE"
assert_eq "parse di" "hilt" "$DI_FRAMEWORK"
assert_eq "parse network" "retrofit" "$NETWORK_LIB"
assert_eq "parse modules" "single" "$MODULE_TYPE"
assert_eq "parse output" "/tmp/test" "$OUTPUT_DIR"
assert_eq "parse non-interactive" "true" "$NON_INTERACTIVE"

# --- Test validate_config catches errors ---

reset_config
NON_INTERACTIVE="true"
APP_NAME="TestApp"; PACKAGE_NAME="com.test.myapp"; MIN_SDK="24"
ARCH_TYPE="mvvm-clean"; DI_FRAMEWORK="hilt"; NETWORK_LIB="retrofit"
MODULE_TYPE="single"; OUTPUT_DIR="/tmp/test"
assert_eq "valid config passes" "0" "$(validate_config 2>/dev/null && echo 0 || echo 1)"

# Bad app name
APP_NAME="1BadName"
assert_eq "reject bad app name" "1" "$(validate_config 2>/dev/null && echo 0 || echo 1)"
APP_NAME="TestApp"

# Bad package
PACKAGE_NAME="bad"
assert_eq "reject bad package" "1" "$(validate_config 2>/dev/null && echo 0 || echo 1)"
PACKAGE_NAME="com.test.myapp"

# Bad min sdk
MIN_SDK="99"
assert_eq "reject bad min sdk" "1" "$(validate_config 2>/dev/null && echo 0 || echo 1)"
MIN_SDK="24"

# Bad arch
ARCH_TYPE="invalid"
assert_eq "reject bad arch" "1" "$(validate_config 2>/dev/null && echo 0 || echo 1)"
ARCH_TYPE="mvvm-clean"

# Bad DI
DI_FRAMEWORK="spring"
assert_eq "reject bad di" "1" "$(validate_config 2>/dev/null && echo 0 || echo 1)"
DI_FRAMEWORK="hilt"

# Bad network
NETWORK_LIB="volley"
assert_eq "reject bad network" "1" "$(validate_config 2>/dev/null && echo 0 || echo 1)"
NETWORK_LIB="retrofit"

# Bad modules
MODULE_TYPE="micro"
assert_eq "reject bad module type" "1" "$(validate_config 2>/dev/null && echo 0 || echo 1)"
MODULE_TYPE="single"

# --- Test all valid arch/di/net options ---

for arch in mvvm-clean mvi-clean mvvm-simple; do
  ARCH_TYPE="$arch"
  assert_eq "accept arch $arch" "0" "$(validate_config 2>/dev/null && echo 0 || echo 1)"
done
ARCH_TYPE="mvvm-clean"

for di in hilt koin metro; do
  DI_FRAMEWORK="$di"
  assert_eq "accept di $di" "0" "$(validate_config 2>/dev/null && echo 0 || echo 1)"
done
DI_FRAMEWORK="hilt"

for net in retrofit ktor; do
  NETWORK_LIB="$net"
  assert_eq "accept net $net" "0" "$(validate_config 2>/dev/null && echo 0 || echo 1)"
done

# --- Results ---

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
echo "All tests passed!"
