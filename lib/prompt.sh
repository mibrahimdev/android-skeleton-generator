#!/usr/bin/env bash
# User prompts and input validation for android-gen

# Config variables (set by parse_args or interactive prompts)
APP_NAME=""
PACKAGE_NAME=""
MIN_SDK=""
ARCH_TYPE=""
DI_FRAMEWORK=""
NETWORK_LIB=""
MODULE_TYPE=""
OUTPUT_DIR=""
NON_INTERACTIVE=""

VALID_ARCHS=("mvvm-clean" "mvi-clean" "mvvm-simple")
VALID_DI=("hilt" "koin" "metro")
VALID_NET=("retrofit" "ktor")
VALID_MODULES=("single" "multi")

# Parse CLI arguments for non-interactive mode
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --non-interactive) NON_INTERACTIVE="true"; shift ;;
      --name)       APP_NAME="$2"; shift 2 ;;
      --package)    PACKAGE_NAME="$2"; shift 2 ;;
      --min-sdk)    MIN_SDK="$2"; shift 2 ;;
      --arch)       ARCH_TYPE="$2"; shift 2 ;;
      --di)         DI_FRAMEWORK="$2"; shift 2 ;;
      --net)        NETWORK_LIB="$2"; shift 2 ;;
      --modules)    MODULE_TYPE="$2"; shift 2 ;;
      --output)     OUTPUT_DIR="$2"; shift 2 ;;
      --help|-h)    show_help; exit 0 ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done
}

# Validate all config values
validate_config() {
  local errors=0

  if ! validate_app_name "$APP_NAME"; then
    log_error "Invalid app name: '$APP_NAME' (must be alphanumeric, start with letter)"
    ((errors++))
  fi

  if ! validate_package_name "$PACKAGE_NAME"; then
    log_error "Invalid package: '$PACKAGE_NAME' (must be reverse-domain, e.g. com.example.myapp)"
    ((errors++))
  fi

  if ! validate_min_sdk "$MIN_SDK"; then
    log_error "Invalid min SDK: '$MIN_SDK' (must be 21-35)"
    ((errors++))
  fi

  if ! array_contains "$ARCH_TYPE" "${VALID_ARCHS[@]}"; then
    log_error "Invalid architecture: '$ARCH_TYPE' (must be one of: ${VALID_ARCHS[*]})"
    ((errors++))
  fi

  if ! array_contains "$DI_FRAMEWORK" "${VALID_DI[@]}"; then
    log_error "Invalid DI framework: '$DI_FRAMEWORK' (must be one of: ${VALID_DI[*]})"
    ((errors++))
  fi

  if ! array_contains "$NETWORK_LIB" "${VALID_NET[@]}"; then
    log_error "Invalid networking: '$NETWORK_LIB' (must be one of: ${VALID_NET[*]})"
    ((errors++))
  fi

  if ! array_contains "$MODULE_TYPE" "${VALID_MODULES[@]}"; then
    log_error "Invalid module type: '$MODULE_TYPE' (must be one of: ${VALID_MODULES[*]})"
    ((errors++))
  fi

  [[ $errors -eq 0 ]]
}

# Helper: check if value is in array
array_contains() {
  local needle="$1"; shift
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

# Interactive prompt for a single value with choices
prompt_choice() {
  local prompt_text="$1"; shift
  local options=("$@")
  local choice

  while true; do
    echo "" >&2
    echo -e "${BLUE}▸ ${prompt_text}${NC}" >&2
    echo "" >&2
    for i in "${!options[@]}"; do
      local opt="${options[$i]}"
      local key="${opt%% *}"       # e.g. "mvvm-clean"
      local rest="${opt#* }"       # e.g. "— MVVM + Clean Architecture (...)"
      # If there's no description (key == rest), just show the key highlighted
      if [[ "$key" == "$rest" ]]; then
        echo -e "  ${GREEN}$((i + 1)))${NC}  ${YELLOW}${key}${NC}" >&2
      else
        echo -e "  ${GREEN}$((i + 1)))${NC}  ${YELLOW}${key}${NC} ${rest}" >&2
      fi
    done
    echo "" >&2
    read -rp "Select [1-${#options[@]}]: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      echo "${options[$((choice - 1))]}"
      return 0
    fi
    log_error "Invalid choice. Please enter a number between 1 and ${#options[@]}."
  done
}

# Interactive prompt for free text with validation
prompt_text() {
  local prompt_text="$1"
  local validator="$2"
  local value

  while true; do
    echo "" >&2
    read -rp "$(echo -e "${BLUE}▸${NC} ${prompt_text}: ")" value
    if $validator "$value"; then
      echo "$value"
      return 0
    fi
    log_error "Invalid input. Try again."
  done
}

# Run interactive prompts to collect all config
collect_config_interactive() {
  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}" >&2
  echo -e "${GREEN}║   Android Skeleton Project Generator     ║${NC}" >&2
  echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}" >&2

  APP_NAME=$(prompt_text "App name (e.g. MyApp)" validate_app_name)
  PACKAGE_NAME=$(prompt_text "Package name (e.g. com.example.myapp)" validate_package_name)

  MIN_SDK=$(prompt_choice "Minimum SDK version:" "21 (Android 5.0)" "24 (Android 7.0)" "26 (Android 8.0)" "28 (Android 9.0)")
  MIN_SDK="${MIN_SDK%% *}"  # Extract just the number

  ARCH_TYPE=$(prompt_choice "Architecture pattern:" \
    "mvvm-clean  — MVVM + Clean Architecture (ViewModel + UseCase + Repository layers)" \
    "mvi-clean   — MVI + Clean Architecture (unidirectional data flow with Intent/State)" \
    "mvvm-simple — MVVM Simple (ViewModel + Repository, no domain layer)")
  ARCH_TYPE="${ARCH_TYPE%% *}"  # Extract the key before the description

  DI_FRAMEWORK=$(prompt_choice "Dependency injection framework:" \
    "hilt  — Dagger Hilt (annotation-based, official Jetpack support)" \
    "koin  — Koin (lightweight, pure Kotlin service locator)" \
    "metro — Metro (KSP-based, compile-time DI by Zac Sweers)")
  DI_FRAMEWORK="${DI_FRAMEWORK%% *}"

  NETWORK_LIB=$(prompt_choice "Networking library:" \
    "retrofit — Retrofit + OkHttp (type-safe HTTP client, industry standard)" \
    "ktor     — Ktor Client (pure Kotlin, coroutine-native, multiplatform-ready)")
  NETWORK_LIB="${NETWORK_LIB%% *}"

  MODULE_TYPE=$(prompt_choice "Module structure:" \
    "single — Single app module (simpler, recommended for starting out)" \
    "multi  — Multi-module (separate domain/data/presentation modules)")
  MODULE_TYPE="${MODULE_TYPE%% *}"

  OUTPUT_DIR="${OUTPUT_DIR:-./$APP_NAME}"
  echo "" >&2
  read -rp "$(echo -e "${BLUE}▸${NC} Output directory [${YELLOW}${OUTPUT_DIR}${NC}]: ")" user_dir
  OUTPUT_DIR="${user_dir:-$OUTPUT_DIR}"
}

# Main config collection entry point
collect_config() {
  if [[ "$NON_INTERACTIVE" == "true" ]]; then
    # Default output dir if not specified
    OUTPUT_DIR="${OUTPUT_DIR:-./$APP_NAME}"
    validate_config
  else
    collect_config_interactive
  fi
}

show_help() {
  cat <<'EOF'
Usage: android-gen.sh [OPTIONS]

Generate an Android skeleton project with preconfigured dependencies.

Options:
  --non-interactive     Run without prompts (requires all flags)
  --name NAME           App name (e.g. MyApp)
  --package PKG         Package name (e.g. com.example.myapp)
  --min-sdk SDK         Minimum SDK version (21-35)
  --arch ARCH           Architecture: mvvm-clean, mvi-clean, mvvm-simple
  --di DI               DI framework: hilt, koin, metro
  --net NET             Networking: retrofit, ktor
  --modules TYPE        Module structure: single, multi
  --output DIR          Output directory (default: ./<name>)
  -h, --help            Show this help

Examples:
  ./android-gen.sh
  ./android-gen.sh --non-interactive --name MyApp --package com.example.myapp \
    --arch mvvm-clean --di hilt --net retrofit --min-sdk 24 --modules single
EOF
}
