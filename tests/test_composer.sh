#!/usr/bin/env bash
# Tests for template composition logic (build_template_vars in generator.sh)

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"
source "$SCRIPT_DIR/../lib/versions.sh"
source "$SCRIPT_DIR/../lib/generator.sh"

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

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    ((PASS++))
  else
    ((FAIL++))
    echo "FAIL: $desc — expected to contain '$needle'"
  fi
}

# Helper to get a template var value
get_tmpl_var() {
  local key="$1" i
  for ((i = 0; i < ${#TMPL_KEYS[@]}; i++)); do
    if [[ "${TMPL_KEYS[$i]}" == "$key" ]]; then
      echo "${TMPL_VALS[$i]}"
      return 0
    fi
  done
}

# --- Setup mock config ---
APP_NAME="TestApp"
PACKAGE_NAME="com.test.myapp"
PACKAGE_PATH="com/test/myapp"
MIN_SDK="24"
COMPILE_SDK="35"
TARGET_SDK="35"
ARCH_TYPE="mvvm-clean"
MODULE_TYPE="single"

# Mock resolved versions
RESOLVED_KEYS=("agp" "kotlin" "compose-bom" "hilt")
RESOLVED_VALS=("8.7.3" "2.1.0" "2024.12.01" "2.53.1")

# --- Test Hilt config ---
DI_FRAMEWORK="hilt"
NETWORK_LIB="retrofit"
MOCK_LIB="mockk"
build_template_vars

assert_contains "hilt: import present" "HiltViewModel" "$(get_tmpl_var HILT_IMPORT)"
assert_eq "hilt: annotation" "@HiltViewModel" "$(get_tmpl_var HILT_ANNOTATION)"
assert_eq "hilt: inject" "@Inject " "$(get_tmpl_var HILT_INJECT)"
assert_contains "hilt: app annotation" "HiltAndroidApp" "$(get_tmpl_var APP_ANNOTATION)"

# --- Test Koin config ---
DI_FRAMEWORK="koin"
build_template_vars

assert_eq "koin: no hilt import" "" "$(get_tmpl_var HILT_IMPORT)"
assert_eq "koin: no hilt annotation" "" "$(get_tmpl_var HILT_ANNOTATION)"
assert_eq "koin: no hilt inject" "" "$(get_tmpl_var HILT_INJECT)"
assert_eq "koin: no app annotation" "" "$(get_tmpl_var APP_ANNOTATION)"

# --- Test MockK config ---
MOCK_LIB="mockk"
DI_FRAMEWORK="hilt"
RESOLVED_KEYS=("agp" "kotlin" "compose-bom" "hilt" "mockk")
RESOLVED_VALS=("8.7.3" "2.1.0" "2024.12.01" "2.53.1" "1.13.14")
build_template_vars

assert_eq "mockk: version entry" "mockk = \"1.13.14\"" "$(get_tmpl_var MOCK_VERSION_ENTRIES)"
assert_contains "mockk: library entry" "io.mockk" "$(get_tmpl_var MOCK_LIBRARY_ENTRIES)"

# --- Test Mockito config ---
MOCK_LIB="mockito"
RESOLVED_KEYS=("agp" "kotlin" "compose-bom" "hilt" "mockito" "mockito-kotlin")
RESOLVED_VALS=("8.7.3" "2.1.0" "2024.12.01" "2.53.1" "5.14.2" "5.4.0")
build_template_vars

assert_contains "mockito: version entry has mockito" "mockito = \"5.14.2\"" "$(get_tmpl_var MOCK_VERSION_ENTRIES)"
assert_contains "mockito: library entry" "org.mockito" "$(get_tmpl_var MOCK_LIBRARY_ENTRIES)"

# --- Test version vars are set ---
MOCK_LIB="mockk"
RESOLVED_KEYS=("agp" "kotlin" "compose-bom" "hilt" "mockk")
RESOLVED_VALS=("8.7.3" "2.1.0" "2024.12.01" "2.53.1" "1.13.14")
build_template_vars

assert_eq "version AGP set" "8.7.3" "$(get_tmpl_var VERSION_AGP)"
assert_eq "version Kotlin set" "2.1.0" "$(get_tmpl_var VERSION_KOTLIN)"
assert_eq "version Compose BOM set" "2024.12.01" "$(get_tmpl_var VERSION_COMPOSE_BOM)"

# --- Test basic vars ---
assert_eq "package name" "com.test.myapp" "$(get_tmpl_var PACKAGE_NAME)"
assert_eq "app name" "TestApp" "$(get_tmpl_var APP_NAME)"
assert_eq "min sdk" "24" "$(get_tmpl_var MIN_SDK)"
assert_eq "feature name" "home" "$(get_tmpl_var FEATURE_NAME)"
assert_eq "feature name pascal" "Home" "$(get_tmpl_var FEATURE_NAME_PASCAL)"

# --- Results ---

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
echo "All tests passed!"
