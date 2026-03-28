#!/usr/bin/env bash
# Post-generation verification - builds the project and runs tests

verify_project() {
  local project_dir="$1"
  local errors=0

  log_info "=== Verification ==="

  # Step 1: Environment check
  log_info "Checking environment..."
  if ! verify_environment; then
    log_error "Environment check failed. Fix the issues above and retry."
    return 1
  fi
  log_success "Environment OK"

  # Step 2: Build
  log_info "Building project (assembleDebug)..."
  if ! run_gradle "$project_dir" "assembleDebug"; then
    log_error "Build failed!"
    ((errors++))
  else
    log_success "Build passed"
  fi

  # Step 3: Tests (debug only - Robolectric needs debug variant)
  log_info "Running tests (testDebugUnitTest)..."
  if ! run_gradle "$project_dir" "testDebugUnitTest"; then
    log_error "Tests failed!"
    ((errors++))
  else
    log_success "All tests passed"
  fi

  # Summary
  echo ""
  if [[ $errors -eq 0 ]]; then
    log_success "=== Verification complete: ALL PASSED ==="
    return 0
  else
    log_error "=== Verification complete: $errors step(s) failed ==="
    return 1
  fi
}

verify_environment() {
  local ok=true

  # Check JAVA_HOME or java on PATH
  if [[ -z "${JAVA_HOME:-}" ]]; then
    if ! command -v java &>/dev/null; then
      log_error "JAVA_HOME not set and java not found on PATH"
      log_info "  Install JDK 17+: https://adoptium.net/"
      ok=false
    fi
  fi

  # Check ANDROID_HOME or ANDROID_SDK_ROOT
  if [[ -z "${ANDROID_HOME:-}" && -z "${ANDROID_SDK_ROOT:-}" ]]; then
    # Check common locations
    local sdk_found=false
    for sdk_path in "$HOME/Library/Android/sdk" "$HOME/Android/Sdk" "/usr/local/lib/android/sdk"; do
      if [[ -d "$sdk_path" ]]; then
        export ANDROID_HOME="$sdk_path"
        sdk_found=true
        break
      fi
    done
    if ! $sdk_found; then
      log_error "ANDROID_HOME not set and Android SDK not found"
      log_info "  Install Android SDK: https://developer.android.com/studio"
      ok=false
    fi
  fi

  # Check gradlew exists and is executable
  # (this is checked per-project in run_gradle)

  $ok
}

run_gradle() {
  local project_dir="$1"
  local task="$2"

  if [[ ! -f "$project_dir/gradlew" ]]; then
    log_error "gradlew not found in $project_dir"
    return 1
  fi

  (cd "$project_dir" && ./gradlew "$task" --no-daemon 2>&1) | while IFS= read -r line; do
    # Show only important lines to keep output manageable
    case "$line" in
      *FAILED*|*ERROR*|*Exception*|*BUILD*)
        echo "  $line"
        ;;
    esac
  done

  # Re-run to get the actual exit code (the pipe above consumes it)
  (cd "$project_dir" && ./gradlew "$task" --no-daemon > /dev/null 2>&1)
}
