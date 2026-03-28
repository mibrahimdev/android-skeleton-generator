# Android Skeleton Project Generator - Design Spec

## Context

We need a CLI tool that generates ready-to-develop Android skeleton projects with all necessary dependencies pre-configured. The tool prompts the user for project configuration (architecture, DI framework, networking library, etc.), resolves the latest stable dependency versions from Maven repositories, generates a complete project with Jetpack Compose UI, and verifies the project builds and tests pass.

This tool lives in `/Volumes/Workspace/AndroidDevUtils` and is implemented as a Bash CLI.

## Tool Format

**Bash/Shell CLI** - portable, no runtime dependencies beyond macOS standard tools + Android SDK/JDK.

## Tool Structure (Approach B: Modular Script + File Templates)

```
AndroidDevUtils/
  android-gen.sh                      # Entry point: arg parsing, orchestration (~300 lines)
  lib/
    prompt.sh                         # Interactive prompts and input validation
    versions.sh                       # Version resolver (Google Maven + Maven Central)
    composer.sh                       # Assembles template manifest based on user choices
    generator.sh                      # Reads templates, replaces {{PLACEHOLDERS}}, writes output
    verify.sh                         # Post-generation verification (build + tests)
    utils.sh                          # Logging, colors, path helpers
  templates/
    gradle/
      libs.versions.toml.tmpl
      settings.gradle.kts.tmpl
      gradle.properties.tmpl
      wrapper/
        gradle-wrapper.properties.tmpl
    build/
      root.build.gradle.kts.tmpl
      app.build.gradle.kts.tmpl
    build/fragments/
      deps-compose.fragment
      deps-hilt.fragment
      deps-koin.fragment
      deps-metro.fragment
      deps-retrofit.fragment
      deps-ktor.fragment
      deps-room.fragment
      deps-datastore.fragment
      deps-navigation.fragment
      deps-test.fragment
      plugins-hilt.fragment
      plugins-koin.fragment
      plugins-metro.fragment
    arch/
      mvvm-clean/
        domain/
          UseCase.kt.tmpl
          Repository.kt.tmpl           # Interface
        data/
          RepositoryImpl.kt.tmpl
          RemoteDataSource.kt.tmpl
          LocalDataSource.kt.tmpl
        presentation/
          ViewModel.kt.tmpl
          Screen.kt.tmpl
        di/
          hilt/AppModule.kt.tmpl, RepositoryModule.kt.tmpl
          koin/AppModule.kt.tmpl
          metro/AppGraph.kt.tmpl
        test/
          ViewModelTest.kt.tmpl
          UseCaseTest.kt.tmpl
          ScreenTest.kt.tmpl           # Robolectric
          RepositoryIntegrationTest.kt.tmpl
      mvi-clean/
        domain/
          UseCase.kt.tmpl
          Repository.kt.tmpl
        data/
          RepositoryImpl.kt.tmpl
          RemoteDataSource.kt.tmpl
          LocalDataSource.kt.tmpl
        presentation/
          ViewModel.kt.tmpl            # MVI-style with reduce()
          Intent.kt.tmpl
          State.kt.tmpl
          SideEffect.kt.tmpl
          Screen.kt.tmpl
        di/
          hilt/AppModule.kt.tmpl
          koin/AppModule.kt.tmpl
          metro/AppGraph.kt.tmpl
        test/
          ViewModelTest.kt.tmpl
          ScreenTest.kt.tmpl
          RepositoryIntegrationTest.kt.tmpl
      mvvm-simple/
        data/
          Repository.kt.tmpl
        ui/
          ViewModel.kt.tmpl
          Screen.kt.tmpl
        test/
          ViewModelTest.kt.tmpl
          ScreenTest.kt.tmpl
    app/
      AndroidManifest.xml.tmpl
      Application.kt.tmpl
      MainActivity.kt.tmpl
      theme/
        Theme.kt.tmpl
        Color.kt.tmpl
        Type.kt.tmpl
      navigation/
        NavGraph.kt.tmpl
    multimodule/
      domain.build.gradle.kts.tmpl
      data.build.gradle.kts.tmpl
      presentation.build.gradle.kts.tmpl
  tests/
    test_version_resolver.sh
    test_generator.sh
    test_composer.sh
```

## User Prompts

When run interactively, the tool prompts for:

1. **App name** - Free text, validated (alphanumeric, no spaces)
2. **Package name** - Validated reverse-domain format (e.g., `com.example.myapp`)
3. **Min SDK** - Choices: 21, 24, 26, 28, or custom (validated range 21-35)
4. **Architecture** - Choices: MVVM + Clean Architecture, MVI + Clean Architecture, MVVM (simple)
5. **DI framework** - Choices: Hilt, Koin, Metro
6. **Networking** - Choices: Retrofit + OkHttp, Ktor Client
7. **Module structure** - Choices: Single module, Multi-module
8. **Output directory** - Defaults to `./<app-name>`

Non-interactive mode supported via CLI flags (e.g., `--name MyApp --package com.example.myapp --arch mvvm-clean --di hilt --net retrofit --min-sdk 24 --modules single --output ./MyApp`).

## Template System

### Placeholder Syntax

Templates use `{{DOUBLE_BRACE}}` placeholders to avoid collision with Kotlin's `$variable` / `${expression}` syntax. This is a critical design choice.

Examples: `{{PACKAGE_NAME}}`, `{{MIN_SDK}}`, `{{APP_NAME}}`, `{{HILT_IMPORT}}`, `{{HILT_ANNOTATION}}`

### Placeholder Replacement

A variable map (bash associative array) is built by `composer.sh` based on user choices:

```bash
declare -A VARS=(
  ["PACKAGE_NAME"]="com.example.myapp"
  ["PACKAGE_PATH"]="com/example/myapp"
  ["MIN_SDK"]="24"
  ["COMPILE_SDK"]="35"
  ["APP_NAME"]="MyApp"
  ["FEATURE_NAME"]="home"
  ["FEATURE_NAME_PASCAL"]="Home"
  ["HILT_IMPORT"]=""        # Set based on DI choice
  ["HILT_ANNOTATION"]=""    # Set based on DI choice
  ["DEPENDENCY_BLOCK"]=""   # Assembled from fragments
  ["PLUGIN_BLOCK"]=""       # Assembled from fragments
)
```

`generator.sh` applies replacements using bash parameter expansion:
```bash
apply_template() {
  local content=$(<"$1")
  for key in "${!VARS[@]}"; do
    content="${content//\{\{${key}\}\}/${VARS[$key]}}"
  done
  echo "$content"
}
```

### Fragment Composition

Build file dependencies and plugins are composed from fragment files. `composer.sh` concatenates the relevant fragments based on user choices and sets `{{DEPENDENCY_BLOCK}}` and `{{PLUGIN_BLOCK}}` in the variable map.

## Version Resolution

### Sources

- **Google Maven** (`dl.google.com/dl/android/maven2/`): AndroidX libraries (Compose BOM, Room, Navigation, Lifecycle, Activity, DataStore, Hilt Navigation Compose)
- **Maven Central** (`search.maven.org` Solr API): Hilt/Dagger, Koin, Metro, Retrofit, OkHttp, Ktor, Kotlinx Serialization, MockK, Turbine, JUnit5, Robolectric

### Stability Filter

Versions containing `alpha`, `beta`, `rc`, `dev` are rejected. Only stable releases are used.

### Caching

Resolved versions are cached at `~/.cache/android-gen/versions.cache` with a 24-hour TTL. Avoids hitting the network on every run. Provides offline fallback with a warning.

### Fallback

Hardcoded known-good versions are baked into `lib/versions.sh` as a last resort if both network and cache fail.

### Output

Generates `gradle/libs.versions.toml` with resolved versions. Only resolves dependencies relevant to the user's choices.

## Dependencies Included

### Always included:
- Kotlin (matching AGP-compatible version)
- Android Gradle Plugin
- Jetpack Compose BOM + UI + Material3 + Foundation + Tooling
- Compose Navigation
- Room (runtime, KTX, compiler)
- Jetpack DataStore (Preferences)
- Kotlinx Coroutines (core + android)
- Lifecycle (ViewModel, runtime, compose)
- Activity Compose

### Based on DI choice:
- **Hilt**: Dagger Hilt Android, Hilt Compiler (KSP), Hilt Navigation Compose
- **Koin**: Koin Android, Koin Compose, Koin Test
- **Metro**: Metro Runtime, Metro Compiler (KSP)

### Based on networking choice:
- **Retrofit**: Retrofit, OkHttp, OkHttp Logging Interceptor, Kotlinx Serialization Converter
- **Ktor**: Ktor Client Android, Ktor Client Content Negotiation, Ktor Serialization Kotlinx JSON

### Testing:
- JUnit5 (Jupiter API + Engine)
- MockK
- Turbine (Flow testing)
- Robolectric
- Compose UI Test (JUnit4 rule + Manifest)
- Kotlinx Coroutines Test
- Room Testing (in-memory database)

## Architecture Patterns

### MVVM + Clean Architecture
Layers: domain (UseCase, Repository interface, Model) → data (RepositoryImpl, RemoteDataSource, LocalDataSource, Room DAO/Database) → presentation (ViewModel with StateFlow, Compose Screen)

### MVI + Clean Architecture
Same as MVVM+Clean but presentation layer adds: Intent (sealed interface), State (data class), SideEffect (sealed interface). ViewModel uses `reduce()` pattern for state transitions.

### MVVM (simple)
Flat structure: data (Repository) → ui (ViewModel, Screen). No UseCase layer, no domain separation.

### Multi-module (optional)
When selected, domain/data/presentation become separate Gradle modules with their own `build.gradle.kts`. The app module depends on all three.

## Generated Project Structure (Example: MVVM+Clean, Single Module, Hilt, Retrofit)

```
MyApp/
  gradle/
    libs.versions.toml
    wrapper/gradle-wrapper.properties
  build.gradle.kts
  settings.gradle.kts
  gradle.properties
  app/
    build.gradle.kts
    src/main/
      AndroidManifest.xml
      java/com/example/myapp/
        MyApp.kt                    # @HiltAndroidApp
        MainActivity.kt             # setContent { NavGraph }
        di/
          AppModule.kt              # @Module @InstallIn(SingletonComponent)
          RepositoryModule.kt
        domain/
          model/Item.kt
          repository/ItemRepository.kt
          usecase/GetItemsUseCase.kt
        data/
          remote/
            ApiService.kt           # Retrofit interface
            RemoteDataSource.kt
          local/
            ItemDao.kt              # Room DAO
            AppDatabase.kt
            LocalDataSource.kt
            PreferencesDataStore.kt  # DataStore
          repository/ItemRepositoryImpl.kt
        presentation/home/
          HomeViewModel.kt
          HomeScreen.kt
        navigation/NavGraph.kt
        ui/theme/
          Theme.kt, Color.kt, Type.kt
    src/test/java/com/example/myapp/
      presentation/home/
        HomeViewModelTest.kt         # JUnit5 + MockK + Turbine
        HomeScreenTest.kt            # Robolectric + Compose UI Test
      domain/usecase/
        GetItemsUseCaseTest.kt
      data/repository/
        ItemRepositoryIntegrationTest.kt  # Room in-memory DB
```

## Verification

`lib/verify.sh` runs after project generation:

1. **Environment check**: Validates `ANDROID_HOME`, `JAVA_HOME`, required SDK levels installed
2. **Build**: `./gradlew assembleDebug --no-daemon` - confirms compilation
3. **Unit + Robolectric + Integration tests**: `./gradlew test --no-daemon` - runs all JVM tests
4. **Report**: Color-coded pass/fail summary with error details on failure
5. **Suggestions**: If a step fails, provides actionable fix suggestions (e.g., missing SDK)

## Tool Self-Tests

Located in `tests/` directory:
- `test_version_resolver.sh` - Tests version fetching with mocked HTTP responses
- `test_generator.sh` - Ensures no `{{PLACEHOLDER}}` remains in generated output
- `test_composer.sh` - Validates correct template assembly per configuration combo
