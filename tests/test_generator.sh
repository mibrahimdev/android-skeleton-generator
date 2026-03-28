#!/usr/bin/env bash
# Tests for lib/generator.sh

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"
source "$SCRIPT_DIR/../lib/generator.sh"

PASS=0
FAIL=0
TMPDIR_TEST=$(mktemp -d)
trap "rm -rf $TMPDIR_TEST" EXIT

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    ((PASS++))
  else
    ((FAIL++))
    echo "FAIL: $desc"
    echo "  expected: '$expected'"
    echo "  actual:   '$actual'"
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    ((PASS++))
  else
    ((FAIL++))
    echo "FAIL: $desc — expected to contain '$needle'"
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    ((FAIL++))
    echo "FAIL: $desc — should NOT contain '$needle'"
  else
    ((PASS++))
  fi
}

# --- Test apply_template_string ---

# Set up template variables
TMPL_KEYS=("PACKAGE_NAME" "APP_NAME" "MIN_SDK" "FEATURE_NAME")
TMPL_VALS=("com.example.myapp" "MyApp" "24" "home")

result=$(apply_template_string 'package {{PACKAGE_NAME}}.{{FEATURE_NAME}}')
assert_eq "replace package and feature" "package com.example.myapp.home" "$result"

result=$(apply_template_string 'minSdk = {{MIN_SDK}}')
assert_eq "replace min sdk" "minSdk = 24" "$result"

# Test Kotlin $ syntax is preserved
result=$(apply_template_string 'val name = "${user.name}"')
assert_contains "preserve kotlin dollar-brace" '${user.name}' "$result"

result=$(apply_template_string 'items.forEach { println($it) }')
assert_contains "preserve kotlin dollar-it" '$it' "$result"

# Test no unreplaced placeholders for known keys
result=$(apply_template_string '{{PACKAGE_NAME}} and {{APP_NAME}} are set')
assert_not_contains "no unreplaced PACKAGE_NAME" "{{PACKAGE_NAME}}" "$result"
assert_not_contains "no unreplaced APP_NAME" "{{APP_NAME}}" "$result"

# Test template with unknown placeholder leaves it (for later passes or debugging)
result=$(apply_template_string '{{UNKNOWN_KEY}} stays')
assert_contains "unknown placeholder preserved" "{{UNKNOWN_KEY}}" "$result"

# --- Test write_generated_file ---

write_generated_file "hello world" "$TMPDIR_TEST/deep/nested/file.kt"
assert_eq "write creates nested dirs" "hello world" "$(cat "$TMPDIR_TEST/deep/nested/file.kt")"

# --- Test apply_template_file ---

echo 'package {{PACKAGE_NAME}}

class {{APP_NAME}}Application : Application() {
    val items = listOf("a").map { "$it-suffix" }
}' > "$TMPDIR_TEST/test.kt.tmpl"

result=$(apply_template_file "$TMPDIR_TEST/test.kt.tmpl")
assert_contains "file: package replaced" "package com.example.myapp" "$result"
assert_contains "file: class name replaced" "class MyAppApplication" "$result"
assert_contains "file: kotlin dollar preserved" '$it' "$result"
assert_not_contains "file: no unreplaced package" "{{PACKAGE_NAME}}" "$result"

# --- Results ---

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
echo "All tests passed!"
