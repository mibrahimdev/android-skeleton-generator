#!/usr/bin/env bash
# Template processor - reads templates, replaces {{PLACEHOLDERS}}, writes output
# Compatible with bash 3.2+

# Template variable store (parallel arrays)
# Set TMPL_KEYS and TMPL_VALS before calling apply functions
TMPL_KEYS=${TMPL_KEYS:-()}
TMPL_VALS=${TMPL_VALS:-()}

# Replace all {{KEY}} placeholders in a string with their values
# Uses pure bash string replacement to handle multiline values correctly
apply_template_string() {
  local content="$1"
  local i

  for ((i = 0; i < ${#TMPL_KEYS[@]}; i++)); do
    local key="${TMPL_KEYS[$i]}"
    local val="${TMPL_VALS[$i]}"
    local placeholder="{{${key}}}"

    # Bash parameter expansion handles multiline values natively
    while [[ "$content" == *"$placeholder"* ]]; do
      content="${content//$placeholder/$val}"
    done
  done

  printf '%s' "$content"
}

# Read a template file and apply placeholder replacements
apply_template_file() {
  local template_path="$1"
  local content
  content=$(<"$template_path")
  apply_template_string "$content"
}

# Write content to a file, creating parent directories as needed
write_generated_file() {
  local content="$1"
  local output_path="$2"

  mkdir -p "$(dirname "$output_path")"
  printf '%s\n' "$content" > "$output_path"
}

# Process a template file and write result to output path
process_template() {
  local template_path="$1"
  local output_path="$2"

  local content
  content=$(apply_template_file "$template_path")
  write_generated_file "$content" "$output_path"
}

# Build the template variable map from the current config
build_template_vars() {
  TMPL_KEYS=()
  TMPL_VALS=()

  _tv() { TMPL_KEYS+=("$1"); TMPL_VALS+=("$2"); }

  _tv "PACKAGE_NAME"       "$PACKAGE_NAME"
  _tv "PACKAGE_PATH"       "$PACKAGE_PATH"
  _tv "APP_NAME"           "$APP_NAME"
  _tv "MIN_SDK"            "$MIN_SDK"
  _tv "COMPILE_SDK"        "${COMPILE_SDK:-35}"
  _tv "TARGET_SDK"         "${TARGET_SDK:-35}"
  _tv "ARCH_TYPE"          "$ARCH_TYPE"
  _tv "DI_FRAMEWORK"       "$DI_FRAMEWORK"
  _tv "NETWORK_LIB"        "$NETWORK_LIB"
  _tv "MODULE_TYPE"        "$MODULE_TYPE"

  # Feature name (default sample feature)
  _tv "FEATURE_NAME"       "home"
  _tv "FEATURE_NAME_PASCAL" "Home"

  # Screen package varies by architecture
  if [[ "$ARCH_TYPE" == "mvvm-simple" ]]; then
    _tv "SCREEN_PACKAGE" "ui.home"
  else
    _tv "SCREEN_PACKAGE" "presentation.home"
  fi

  # Versions from resolver
  local i
  for ((i = 0; i < ${#RESOLVED_KEYS[@]}; i++)); do
    local upper_key
    upper_key=$(echo "${RESOLVED_KEYS[$i]}" | tr '[:lower:]-' '[:upper:]_')
    _tv "VERSION_${upper_key}" "${RESOLVED_VALS[$i]}"
  done

  # DI-specific placeholders
  case "$DI_FRAMEWORK" in
    hilt)
      _tv "HILT_IMPORT" "import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject"
      _tv "HILT_ANNOTATION" "@HiltViewModel"
      _tv "HILT_INJECT" "@Inject "
      _tv "APP_ANNOTATION" "@HiltAndroidApp"
      _tv "APP_ANNOTATION_IMPORT" "import dagger.hilt.android.HiltAndroidApp"
      _tv "APP_ONCREATE" ""
      ;;
    koin)
      _tv "HILT_IMPORT" ""
      _tv "HILT_ANNOTATION" ""
      _tv "HILT_INJECT" ""
      _tv "APP_ANNOTATION" ""
      _tv "APP_ANNOTATION_IMPORT" "import ${PACKAGE_NAME}.di.appModule
import org.koin.android.ext.koin.androidContext
import org.koin.core.context.startKoin"
      _tv "APP_ONCREATE" "    override fun onCreate() {
        super.onCreate()
        startKoin {
            androidContext(this@${APP_NAME}Application)
            modules(appModule)
        }
    }"
      ;;
    metro)
      _tv "HILT_IMPORT" ""
      _tv "HILT_ANNOTATION" ""
      _tv "HILT_INJECT" ""
      _tv "APP_ANNOTATION" ""
      _tv "APP_ANNOTATION_IMPORT" ""
      _tv "APP_ONCREATE" ""
      ;;
  esac

  # Build dependency and plugin blocks from fragments
  dep_block=""
  app_plugin_block=""
  root_plugin_block=""
  local fragments_dir="$SCRIPT_DIR/templates/build/fragments"

  # Always-included fragments
  for frag in deps-compose deps-navigation deps-test; do
    if [[ -f "$fragments_dir/${frag}.fragment" ]]; then
      dep_block+="$(cat "$fragments_dir/${frag}.fragment")"$'\n'
    fi
  done

  # DI fragment
  if [[ -f "$fragments_dir/deps-${DI_FRAMEWORK}.fragment" ]]; then
    dep_block+="$(cat "$fragments_dir/deps-${DI_FRAMEWORK}.fragment")"$'\n'
  fi
  if [[ -f "$fragments_dir/plugins-${DI_FRAMEWORK}.fragment" ]]; then
    local plugin_line
    plugin_line="$(cat "$fragments_dir/plugins-${DI_FRAMEWORK}.fragment")"
    if [[ -n "$plugin_line" ]]; then
      app_plugin_block+="$plugin_line"$'\n'
      # Root version adds "apply false"
      root_plugin_block+="$(echo "$plugin_line" | sed 's/)/) apply false/')"$'\n'
    fi
  fi

  _tv "DEPENDENCY_BLOCK" "$dep_block"
  _tv "PLUGIN_BLOCK" "$app_plugin_block"
  _tv "ROOT_PLUGIN_BLOCK" "$root_plugin_block"
}

# Main generation entry point
compose_and_generate() {
  build_template_vars

  local tmpl_dir="$SCRIPT_DIR/templates"
  local out="$OUTPUT_DIR"
  local src="$out/app/src/main/java/$PACKAGE_PATH"
  local test_dir="$out/app/src/test/java/$PACKAGE_PATH"

  # Create output directory
  mkdir -p "$out"

  # --- Static files ---
  mkdir -p "$out/app"

  cat > "$out/.gitignore" << 'GITIGNORE'
*.iml
.gradle
/local.properties
/.idea
.DS_Store
/build
/captures
.externalNativeBuild
.cxx
local.properties
GITIGNORE

  cat > "$out/app/proguard-rules.pro" << 'PROGUARD'
# Add project specific ProGuard rules here.
PROGUARD

  # Test AndroidManifest for Robolectric/Compose tests
  mkdir -p "$out/app/src/test"
  cat > "$out/app/src/test/AndroidManifest.xml" << TESTMANIFEST
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application>
        <activity android:name="androidx.activity.ComponentActivity" android:exported="false" />
    </application>
</manifest>
TESTMANIFEST

  mkdir -p "$out/app/src/main/res/values"
  cat > "$out/app/src/main/res/values/strings.xml" << STRINGS
<resources>
    <string name="app_name">$APP_NAME</string>
</resources>
STRINGS

  # --- Gradle files ---
  process_template "$tmpl_dir/gradle/libs.versions.toml.tmpl" "$out/gradle/libs.versions.toml"
  process_template "$tmpl_dir/gradle/settings.gradle.kts.tmpl" "$out/settings.gradle.kts"
  process_template "$tmpl_dir/gradle/gradle.properties.tmpl" "$out/gradle.properties"
  process_template "$tmpl_dir/gradle/wrapper/gradle-wrapper.properties.tmpl" "$out/gradle/wrapper/gradle-wrapper.properties"

  # --- Build files ---
  process_template "$tmpl_dir/build/root.build.gradle.kts.tmpl" "$out/build.gradle.kts"
  process_template "$tmpl_dir/build/app.build.gradle.kts.tmpl" "$out/app/build.gradle.kts"

  # --- App files ---
  process_template "$tmpl_dir/app/AndroidManifest.xml.tmpl" "$out/app/src/main/AndroidManifest.xml"
  process_template "$tmpl_dir/app/Application.kt.tmpl" "$src/${APP_NAME}Application.kt"
  process_template "$tmpl_dir/app/MainActivity.kt.tmpl" "$src/MainActivity.kt"

  # --- Theme ---
  process_template "$tmpl_dir/app/theme/Theme.kt.tmpl" "$src/ui/theme/Theme.kt"
  process_template "$tmpl_dir/app/theme/Color.kt.tmpl" "$src/ui/theme/Color.kt"
  process_template "$tmpl_dir/app/theme/Type.kt.tmpl" "$src/ui/theme/Type.kt"

  # --- Navigation ---
  process_template "$tmpl_dir/app/navigation/NavGraph.kt.tmpl" "$src/navigation/NavGraph.kt"

  # --- Architecture-specific files ---
  local arch_dir="$tmpl_dir/arch/$ARCH_TYPE"

  case "$ARCH_TYPE" in
    mvvm-clean|mvi-clean)
      # Domain layer
      process_template "$arch_dir/domain/Repository.kt.tmpl" "$src/domain/repository/GreetingRepository.kt"
      process_template "$arch_dir/domain/UseCase.kt.tmpl" "$src/domain/usecase/GetGreetingUseCase.kt"

      # Data layer
      process_template "$arch_dir/data/LocalDataSource.kt.tmpl" "$src/data/local/LocalDataSource.kt"
      process_template "$arch_dir/data/RepositoryImpl.kt.tmpl" "$src/data/repository/GreetingRepositoryImpl.kt"

      # Presentation
      process_template "$arch_dir/presentation/ViewModel.kt.tmpl" "$src/presentation/home/HomeViewModel.kt"
      process_template "$arch_dir/presentation/Screen.kt.tmpl" "$src/presentation/home/HomeScreen.kt"

      # MVI extras
      if [[ "$ARCH_TYPE" == "mvi-clean" ]]; then
        process_template "$arch_dir/presentation/Intent.kt.tmpl" "$src/presentation/home/HomeIntent.kt"
        process_template "$arch_dir/presentation/State.kt.tmpl" "$src/presentation/home/HomeState.kt"
        process_template "$arch_dir/presentation/SideEffect.kt.tmpl" "$src/presentation/home/HomeSideEffect.kt"
      fi

      # DI
      local di_dir="$arch_dir/di/$DI_FRAMEWORK"
      if [[ -d "$di_dir" ]]; then
        for tmpl in "$di_dir"/*.kt.tmpl; do
          [[ -f "$tmpl" ]] || continue
          local filename
          filename=$(basename "$tmpl" .tmpl)
          process_template "$tmpl" "$src/di/$filename"
        done
      fi

      # Tests
      if [[ -f "$arch_dir/test/ViewModelTest.kt.tmpl" ]]; then
        process_template "$arch_dir/test/ViewModelTest.kt.tmpl" "$test_dir/presentation/home/HomeViewModelTest.kt"
      fi
      if [[ -f "$arch_dir/test/UseCaseTest.kt.tmpl" ]]; then
        process_template "$arch_dir/test/UseCaseTest.kt.tmpl" "$test_dir/domain/usecase/GetGreetingUseCaseTest.kt"
      fi
      if [[ -f "$arch_dir/test/ScreenTest.kt.tmpl" ]]; then
        process_template "$arch_dir/test/ScreenTest.kt.tmpl" "$test_dir/presentation/home/HomeScreenTest.kt"
      fi
      ;;

    mvvm-simple)
      # Data
      process_template "$arch_dir/data/Repository.kt.tmpl" "$src/data/repository/GreetingRepository.kt"

      # UI
      process_template "$arch_dir/ui/ViewModel.kt.tmpl" "$src/ui/home/HomeViewModel.kt"
      process_template "$arch_dir/ui/Screen.kt.tmpl" "$src/ui/home/HomeScreen.kt"

      # DI
      local di_dir="$arch_dir/di/$DI_FRAMEWORK"
      if [[ -d "$di_dir" ]]; then
        for tmpl in "$di_dir"/*.kt.tmpl; do
          [[ -f "$tmpl" ]] || continue
          local filename
          filename=$(basename "$tmpl" .tmpl)
          process_template "$tmpl" "$src/di/$filename"
        done
      fi

      # Tests
      if [[ -f "$arch_dir/test/ViewModelTest.kt.tmpl" ]]; then
        process_template "$arch_dir/test/ViewModelTest.kt.tmpl" "$test_dir/ui/home/HomeViewModelTest.kt"
      fi
      if [[ -f "$arch_dir/test/ScreenTest.kt.tmpl" ]]; then
        process_template "$arch_dir/test/ScreenTest.kt.tmpl" "$test_dir/ui/home/HomeScreenTest.kt"
      fi
      ;;
  esac

  # --- Copy Gradle wrapper ---
  copy_gradle_wrapper "$out"

  log_success "Project files generated at: $out"
}

# Copy or download Gradle wrapper
copy_gradle_wrapper() {
  local out="$1"
  local wrapper_dir="$out/gradle/wrapper"
  mkdir -p "$wrapper_dir"

  # Generate wrapper in a temporary clean directory to avoid build script errors
  if command -v gradle &>/dev/null; then
    log_info "Generating Gradle wrapper..."
    local tmpdir
    tmpdir=$(mktemp -d)
    touch "$tmpdir/settings.gradle"
    (cd "$tmpdir" && gradle wrapper --gradle-version 8.11.1 --no-daemon 2>/dev/null) && {
      cp "$tmpdir/gradlew" "$out/gradlew"
      cp "$tmpdir/gradlew.bat" "$out/gradlew.bat" 2>/dev/null || true
      cp "$tmpdir/gradle/wrapper/gradle-wrapper.jar" "$wrapper_dir/gradle-wrapper.jar"
      chmod +x "$out/gradlew"
      rm -rf "$tmpdir"
      return 0
    }
    rm -rf "$tmpdir"
  fi

  download_gradle_wrapper "$out" "$wrapper_dir"
}

download_gradle_wrapper() {
  local out="$1"
  local wrapper_dir="$2"

  # Download gradle-wrapper.jar from Gradle distributions
  local jar_url="https://raw.githubusercontent.com/niclasmattsson/gradle-wrapper/main/gradle-wrapper.jar"
  curl -sfL --max-time 30 -o "$wrapper_dir/gradle-wrapper.jar" "$jar_url" 2>/dev/null || {
    # Alternative: try to find it locally
    local local_wrapper
    local_wrapper=$(find "$HOME/.gradle/wrapper" -name "gradle-wrapper.jar" -print -quit 2>/dev/null)
    if [[ -n "$local_wrapper" ]]; then
      cp "$local_wrapper" "$wrapper_dir/gradle-wrapper.jar"
    else
      log_warn "Could not download gradle-wrapper.jar. Run 'gradle wrapper' in the project directory."
    fi
  }

  # Create gradlew script (standard Gradle wrapper script, simplified)
  cat > "$out/gradlew" << 'GRADLEW_EOF'
#!/bin/sh
##
## Gradle start up script for POSIX generated by android-gen
##

APP_NAME="Gradle"
APP_BASE_NAME=$(basename "$0")
DEFAULT_JVM_OPTS='"-Xmx64m" "-Xms64m"'

PRG="$0"
while [ -h "$PRG" ] ; do
    ls=$(ls -ld "$PRG")
    link=$(expr "$ls" : '.*-> \(.*\)$')
    if expr "$link" : '/.*' > /dev/null; then
        PRG="$link"
    else
        PRG=$(dirname "$PRG")/"$link"
    fi
done
SAVED="$(pwd)"
cd "$(dirname "$PRG")/" >/dev/null
APP_HOME="$(pwd -P)"
cd "$SAVED" >/dev/null

CLASSPATH=$APP_HOME/gradle/wrapper/gradle-wrapper.jar

# Determine the Java command to use
if [ -n "$JAVA_HOME" ] ; then
    JAVACMD="$JAVA_HOME/bin/java"
else
    JAVACMD="java"
fi

exec "$JAVACMD" $DEFAULT_JVM_OPTS $JAVA_OPTS -classpath "$CLASSPATH" org.gradle.wrapper.GradleWrapperMain "$@"
GRADLEW_EOF
  chmod +x "$out/gradlew"

  # Create gradlew.bat (simplified Windows version)
  cat > "$out/gradlew.bat" << 'GRADLEWBAT_EOF'
@rem Gradle startup script for Windows
@if "%DEBUG%"=="" @echo off
set DEFAULT_JVM_OPTS="-Xmx64m" "-Xms64m"
set DIRNAME=%~dp0
set CLASSPATH=%DIRNAME%\gradle\wrapper\gradle-wrapper.jar
@rem Find java.exe
if defined JAVA_HOME goto findJavaFromJavaHome
set JAVA_EXE=java.exe
goto execute
:findJavaFromJavaHome
set JAVA_HOME=%JAVA_HOME:"=%
set JAVA_EXE=%JAVA_HOME%/bin/java.exe
:execute
"%JAVA_EXE%" %DEFAULT_JVM_OPTS% %JAVA_OPTS% -classpath "%CLASSPATH%" org.gradle.wrapper.GradleWrapperMain %*
:end
GRADLEWBAT_EOF
}
