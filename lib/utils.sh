#!/usr/bin/env bash
# Shared utilities for android-gen

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[OK]${NC} $*" >&2; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# --- Validation ---

# Validates reverse-domain package name (at least 3 segments, lowercase, no hyphens)
validate_package_name() {
  local name="$1"
  [[ -n "$name" ]] || return 1
  # Must be lowercase alphanumeric segments separated by dots, at least 3 segments
  [[ "$name" =~ ^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*){2,}$ ]] || return 1
  return 0
}

# Validates app name (alphanumeric, starts with letter, no spaces/special chars)
validate_app_name() {
  local name="$1"
  [[ -n "$name" ]] || return 1
  [[ "$name" =~ ^[a-zA-Z][a-zA-Z0-9]*$ ]] || return 1
  return 0
}

# Validates min SDK (integer between 21 and 35)
validate_min_sdk() {
  local sdk="$1"
  [[ -n "$sdk" ]] || return 1
  [[ "$sdk" =~ ^[0-9]+$ ]] || return 1
  (( sdk >= 21 && sdk <= 35 )) || return 1
  return 0
}

# Checks that a command exists on PATH
ensure_command_exists() {
  command -v "$1" &>/dev/null
}
