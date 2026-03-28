#!/usr/bin/env bash
# Android Skeleton Project Generator
# Generates ready-to-develop Android projects with preconfigured dependencies.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library modules
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/prompt.sh"
source "$SCRIPT_DIR/lib/versions.sh"
source "$SCRIPT_DIR/lib/generator.sh"
source "$SCRIPT_DIR/lib/verify.sh"

main() {
  parse_args "$@"

  if [[ "${NON_INTERACTIVE:-}" != "true" ]]; then
    collect_config_interactive
  else
    # Default output dir
    OUTPUT_DIR="${OUTPUT_DIR:-./$APP_NAME}"
    if ! validate_config; then
      log_error "Configuration validation failed. Use --help for usage."
      exit 1
    fi
  fi

  log_info "Configuration:"
  log_info "  App name:     $APP_NAME"
  log_info "  Package:      $PACKAGE_NAME"
  log_info "  Min SDK:      $MIN_SDK"
  log_info "  Architecture: $ARCH_TYPE"
  log_info "  DI:           $DI_FRAMEWORK"
  log_info "  Networking:   $NETWORK_LIB"
  log_info "  Modules:      $MODULE_TYPE"
  log_info "  Output:       $OUTPUT_DIR"

  # Compute derived values
  PACKAGE_PATH="${PACKAGE_NAME//./\/}"
  COMPILE_SDK="35"
  TARGET_SDK="35"

  # Phase: Resolve versions
  log_info "Resolving latest stable dependency versions..."
  resolve_all_versions

  # Phase: Compose and generate
  log_info "Generating project..."
  compose_and_generate

  # Phase: Verify
  log_info "Verifying generated project..."
  if verify_project "$OUTPUT_DIR"; then
    echo ""
    log_success "Done! Your project is ready at: $OUTPUT_DIR"
    log_info "Next steps:"
    log_info "  cd $OUTPUT_DIR"
    log_info "  Open in Android Studio"
  else
    echo ""
    log_warn "Project generated but verification had issues."
    log_info "Check the errors above and try building manually."
  fi
}

main "$@"
