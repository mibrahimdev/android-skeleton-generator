#!/usr/bin/env bash
# Version resolver - fetches latest stable versions from Google Maven and Maven Central
# Compatible with bash 3.2+ (no associative arrays)

CACHE_DIR="${HOME}/.cache/android-gen"
CACHE_FILE="${CACHE_DIR}/versions.cache"
CACHE_TTL=86400  # 24 hours in seconds

# --- Key-value store using parallel arrays ---
# Bash 3.2 doesn't support associative arrays, so we use index-based lookup.

FALLBACK_KEYS=()
FALLBACK_VALS=()

_fb() { FALLBACK_KEYS+=("$1"); FALLBACK_VALS+=("$2"); }

# Fallback known-good versions
_fb "agp"                    "8.7.3"
_fb "kotlin"                 "2.1.0"
_fb "ksp"                    "2.1.0-1.0.29"
_fb "compose-bom"            "2024.12.01"
_fb "activity-compose"       "1.9.3"
_fb "lifecycle"              "2.8.7"
_fb "navigation-compose"     "2.8.5"
_fb "room"                   "2.6.1"
_fb "datastore"              "1.1.1"
_fb "hilt"                   "2.53.1"
_fb "hilt-navigation-compose" "1.2.0"
_fb "koin"                   "4.0.1"
_fb "metro"                  "0.3.8"
_fb "retrofit"               "2.11.0"
_fb "okhttp"                 "4.12.0"
_fb "ktor"                   "3.0.3"
_fb "kotlinx-serialization"  "1.7.3"
_fb "junit5"                 "5.10.3"
_fb "mockk"                  "1.13.14"
_fb "turbine"                "1.2.0"
_fb "robolectric"            "4.14.1"
_fb "coroutines"             "1.9.0"

# Lookup a fallback version by key
get_fallback() {
  local key="$1"
  local i
  for ((i = 0; i < ${#FALLBACK_KEYS[@]}; i++)); do
    if [[ "${FALLBACK_KEYS[$i]}" == "$key" ]]; then
      echo "${FALLBACK_VALS[$i]}"
      return 0
    fi
  done
  return 1
}

# Dependency coordinate map: logical-name → source:group:artifact
COORD_KEYS=()
COORD_VALS=()

_cd() { COORD_KEYS+=("$1"); COORD_VALS+=("$2"); }

# Google Maven (AndroidX)
_cd "compose-bom"            "google:androidx.compose:compose-bom"
_cd "activity-compose"       "google:androidx.activity:activity-compose"
_cd "lifecycle"              "google:androidx.lifecycle:lifecycle-viewmodel-ktx"
_cd "navigation-compose"     "google:androidx.navigation:navigation-compose"
_cd "room"                   "google:androidx.room:room-runtime"
_cd "datastore"              "google:androidx.datastore:datastore-preferences"
_cd "hilt-navigation-compose" "google:androidx.hilt:hilt-navigation-compose"
# Maven Central
_cd "agp"                    "google:com.android.tools.build:gradle"
_cd "kotlin"                 "central:org.jetbrains.kotlin:kotlin-stdlib"
_cd "ksp"                    "central:com.google.devtools.ksp:symbol-processing-api"
_cd "hilt"                   "central:com.google.dagger:hilt-android"
_cd "koin"                   "central:io.insert-koin:koin-android"
_cd "metro"                  "central:dev.zacsweers.metro:runtime"
_cd "retrofit"               "central:com.squareup.retrofit2:retrofit"
_cd "okhttp"                 "central:com.squareup.okhttp3:okhttp"
_cd "ktor"                   "central:io.ktor:ktor-client-android"
_cd "kotlinx-serialization"  "central:org.jetbrains.kotlinx:kotlinx-serialization-json"
_cd "junit5"                 "central:org.junit.jupiter:junit-jupiter-api"
_cd "mockk"                  "central:io.mockk:mockk"
_cd "turbine"                "central:app.cash.turbine:turbine"
_cd "robolectric"            "central:org.robolectric:robolectric"
_cd "coroutines"             "central:org.jetbrains.kotlinx:kotlinx-coroutines-core"

get_coord() {
  local key="$1"
  local i
  for ((i = 0; i < ${#COORD_KEYS[@]}; i++)); do
    if [[ "${COORD_KEYS[$i]}" == "$key" ]]; then
      echo "${COORD_VALS[$i]}"
      return 0
    fi
  done
  return 1
}

# Resolved versions store
RESOLVED_KEYS=()
RESOLVED_VALS=()

set_resolved() {
  local key="$1" val="$2"
  RESOLVED_KEYS+=("$key")
  RESOLVED_VALS+=("$val")
}

get_resolved() {
  local key="$1"
  local i
  for ((i = 0; i < ${#RESOLVED_KEYS[@]}; i++)); do
    if [[ "${RESOLVED_KEYS[$i]}" == "$key" ]]; then
      echo "${RESOLVED_VALS[$i]}"
      return 0
    fi
  done
  return 1
}

# --- Parsing functions ---

# Filter a comma-separated version list to return the latest stable version
filter_stable_version() {
  local versions_csv="$1"
  [[ -z "$versions_csv" ]] && return 0

  local latest=""
  local IFS=','
  for v in $versions_csv; do
    v="${v## }"  # Trim leading whitespace
    v="${v%% }"  # Trim trailing whitespace
    [[ -z "$v" ]] && continue
    # Skip pre-release versions
    case "$v" in
      *alpha*|*beta*|*rc*|*dev*|*SNAPSHOT*) continue ;;
    esac
    latest="$v"
  done
  echo "$latest"
}

# Parse Google Maven group-index.xml to get version for an artifact
parse_google_maven_xml() {
  local xml="$1"
  local artifact="$2"

  local versions_attr
  versions_attr=$(echo "$xml" | grep -o "<${artifact} versions=\"[^\"]*\"" | head -1 | sed "s/<${artifact} versions=\"//;s/\"//")
  [[ -z "$versions_attr" ]] && return 0

  filter_stable_version "$versions_attr"
}

# Parse Maven Central Solr JSON response to get latest stable version
parse_maven_central_json() {
  local json="$1"

  local versions
  versions=$(echo "$json" | grep -oE '"v":\s*"[^"]*"' | sed 's/"v":[[:space:]]*"//;s/"//')
  [[ -z "$versions" ]] && return 0

  while IFS= read -r v; do
    case "$v" in
      *alpha*|*beta*|*rc*|*dev*|*SNAPSHOT*) continue ;;
    esac
    echo "$v"
    return 0
  done <<< "$versions"
}

# --- Network fetch functions ---

fetch_google_maven_version() {
  local group="$1" artifact="$2"
  local group_path="${group//./\/}"
  local url="https://dl.google.com/dl/android/maven2/${group_path}/group-index.xml"

  local xml
  xml=$(curl -sf --max-time 10 "$url" 2>/dev/null) || return 1
  parse_google_maven_xml "$xml" "$artifact"
}

fetch_maven_central_version() {
  local group="$1" artifact="$2"
  local url="https://search.maven.org/solrsearch/select?q=g:${group}+AND+a:${artifact}&core=gav&rows=20&wt=json"

  local json
  json=$(curl -sf --max-time 10 "$url" 2>/dev/null) || return 1
  parse_maven_central_json "$json"
}

# --- Cache functions ---

cache_read() {
  local key="$1"
  [[ ! -f "$CACHE_FILE" ]] && return 1

  local cache_age
  if [[ "$(uname)" == "Darwin" ]]; then
    cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE") ))
  else
    cache_age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
  fi
  (( cache_age > CACHE_TTL )) && return 1

  local val
  val=$(grep "^${key}=" "$CACHE_FILE" 2>/dev/null | head -1 | cut -d= -f2)
  [[ -n "$val" ]] && echo "$val" && return 0
  return 1
}

cache_write() {
  local key="$1" value="$2"
  mkdir -p "$CACHE_DIR"

  if [[ -f "$CACHE_FILE" ]]; then
    grep -v "^${key}=" "$CACHE_FILE" > "${CACHE_FILE}.tmp" 2>/dev/null || true
    mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
  fi

  echo "${key}=${value}" >> "$CACHE_FILE"
}

# --- Main resolution ---

resolve_version() {
  local name="$1"

  # Try cache first
  local cached
  cached=$(cache_read "$name" 2>/dev/null) || true
  if [[ -n "$cached" ]]; then
    echo "$cached"
    return 0
  fi

  # Fetch from network
  local coord
  coord=$(get_coord "$name" 2>/dev/null) || true
  if [[ -n "$coord" ]]; then
    local source group artifact
    IFS=: read -r source group artifact <<< "$coord"

    local version=""
    if [[ "$source" == "google" ]]; then
      version=$(fetch_google_maven_version "$group" "$artifact" 2>/dev/null) || true
    elif [[ "$source" == "central" ]]; then
      version=$(fetch_maven_central_version "$group" "$artifact" 2>/dev/null) || true
    fi

    if [[ -n "$version" ]]; then
      cache_write "$name" "$version"
      echo "$version"
      return 0
    fi
  fi

  # Fallback
  local fallback
  fallback=$(get_fallback "$name" 2>/dev/null) || true
  if [[ -n "$fallback" ]]; then
    log_warn "Using fallback version for $name: $fallback"
    echo "$fallback"
    return 0
  fi

  log_error "Could not resolve version for: $name"
  return 1
}

resolve_all_versions() {
  local always_deps="agp kotlin ksp compose-bom activity-compose lifecycle navigation-compose room datastore kotlinx-serialization coroutines junit5 mockk turbine robolectric"

  local di_deps=""
  case "${DI_FRAMEWORK:-hilt}" in
    hilt)  di_deps="hilt hilt-navigation-compose" ;;
    koin)  di_deps="koin" ;;
    metro) di_deps="metro" ;;
  esac

  local net_deps=""
  case "${NETWORK_LIB:-retrofit}" in
    retrofit) net_deps="retrofit okhttp" ;;
    ktor)     net_deps="ktor" ;;
  esac

  local all_deps="$always_deps $di_deps $net_deps"

  if [[ "${RESOLVE_LATEST:-}" == "true" ]]; then
    # --latest flag: try network, fall back to hardcoded
    for dep in $all_deps; do
      local version
      version=$(resolve_version "$dep") || true
      if [[ -n "$version" ]]; then
        set_resolved "$dep" "$version"
      else
        local fb
        fb=$(get_fallback "$dep" 2>/dev/null) || true
        set_resolved "$dep" "${fb:-UNKNOWN}"
      fi
    done
  else
    # Default: use hardcoded versions (tested and guaranteed compatible)
    log_info "Using tested dependency versions (pass --latest to fetch newest from Maven)"
    for dep in $all_deps; do
      local fb
      fb=$(get_fallback "$dep" 2>/dev/null) || true
      set_resolved "$dep" "${fb:-UNKNOWN}"
    done
  fi
}
