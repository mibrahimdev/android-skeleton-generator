# Android Skeleton Generator

A Bash CLI tool that generates ready-to-develop Android projects with preconfigured architecture, dependency injection, networking, and test suites. Run it, answer a few questions, and get a project that builds and passes tests out of the box.

## Requirements

- macOS or Linux
- Bash 3.2+
- JDK 17+
- Android SDK (with `ANDROID_HOME` set)
- `curl` (for fetching dependency versions)
- `gradle` (optional, for generating the Gradle wrapper)

## Quick Start

```bash
git clone https://github.com/mibrahimdev/android-skeleton-generator.git
cd android-skeleton-generator
./android-gen.sh
```

The interactive wizard will ask for:

1. **App name** - e.g. `MyApp`
2. **Package name** - e.g. `com.example.myapp`
3. **Min SDK** - 21, 24, 26, or 28
4. **Architecture** - MVVM + Clean Architecture, MVI + Clean Architecture, or MVVM Simple
5. **DI framework** - Hilt or Koin
6. **Networking** - Retrofit + OkHttp or Ktor
7. **Module structure** - Single module or multi-module
8. **Output directory**

After generation, the tool automatically verifies the project builds and all tests pass.

## Non-Interactive Mode

```bash
./android-gen.sh --non-interactive \
  --name MyApp \
  --package com.example.myapp \
  --arch mvvm-clean \
  --di hilt \
  --net retrofit \
  --min-sdk 24 \
  --modules single \
  --output ./MyApp
```

### CLI Flags

| Flag | Values | Description |
|------|--------|-------------|
| `--name` | string | App name (alphanumeric, starts with letter) |
| `--package` | string | Package name (reverse-domain, min 3 segments) |
| `--arch` | `mvvm-clean`, `mvi-clean`, `mvvm-simple` | Architecture pattern |
| `--di` | `hilt`, `koin` | Dependency injection framework |
| `--net` | `retrofit`, `ktor` | Networking library |
| `--min-sdk` | `21`-`35` | Minimum SDK version |
| `--modules` | `single`, `multi` | Module structure |
| `--output` | path | Output directory (default: `./<name>`) |
| `--non-interactive` | | Run without prompts |
| `-h`, `--help` | | Show help |

## What Gets Generated

A complete Android project with Jetpack Compose that compiles, runs, and has passing tests. The generated app displays a "Hello World" message that flows through all layers of the chosen architecture. Here's what's included for MVVM + Clean Architecture with Hilt as an example:

```
MyApp/
  gradle/libs.versions.toml        # Version catalog (tested stable versions)
  build.gradle.kts                  # Root build file
  settings.gradle.kts
  app/
    build.gradle.kts
    src/main/java/com/example/myapp/
      MyAppApplication.kt           # @HiltAndroidApp
      MainActivity.kt               # Compose entry point
      di/                           # Hilt modules
      domain/
        repository/GreetingRepository.kt  # Interface
        usecase/GetGreetingUseCase.kt
      data/
        local/LocalDataSource.kt    # Returns "Hello World" via Flow
        repository/GreetingRepositoryImpl.kt
      presentation/home/
        HomeViewModel.kt            # StateFlow + coroutines
        HomeScreen.kt               # Compose UI
      navigation/NavGraph.kt
      ui/theme/                     # Material3 theme
    src/test/java/.../
      HomeViewModelTest.kt          # JUnit5 + MockK + Turbine
      GetGreetingUseCaseTest.kt     # JUnit5 + MockK
      HomeScreenTest.kt             # Robolectric + Compose UI Test
```

## Architecture Patterns

### MVVM + Clean Architecture
Three layers with clear separation: **Domain** (UseCase, Repository interface, Model) -> **Data** (Repository impl, data sources, Room, API) -> **Presentation** (ViewModel with StateFlow, Compose Screen).

### MVI + Clean Architecture
Same layers as MVVM + Clean, but the presentation layer uses unidirectional data flow with **Intent** (sealed interface), **State** (data class), and **SideEffect** (sealed interface). The ViewModel exposes a `processIntent()` function and uses a `reduce()` pattern.

### MVVM Simple
Flat structure without a domain layer: **Data** (Repository) -> **UI** (ViewModel, Screen). Good for smaller projects.

## Dependencies Included

### Always included
- Jetpack Compose (BOM + UI + Material3 + Foundation + Tooling)
- Compose Navigation
- Room (runtime + KTX + compiler)
- Jetpack DataStore Preferences
- Kotlinx Coroutines (core + android)
- Lifecycle (ViewModel + runtime + compose)
- Activity Compose
- Kotlinx Serialization JSON

### DI (one of)
- **Hilt**: Dagger Hilt Android + Compiler (KSP) + Navigation Compose
- **Koin**: Koin Android + Compose + Test

### Networking (one of)
- **Retrofit**: Retrofit + OkHttp + Logging Interceptor + Kotlinx Serialization Converter
- **Ktor**: Ktor Client Android + Content Negotiation + Kotlinx JSON + Logging

### Testing
- JUnit 5 (Jupiter API + Engine + Vintage Engine)
- MockK
- Turbine (Flow testing)
- Robolectric
- Compose UI Test (JUnit4 rule + manifest)
- Kotlinx Coroutines Test
- AndroidX Test Core

## Version Resolution

By default, the tool uses tested hardcoded versions that are guaranteed compatible. Use `--latest` to fetch the latest stable versions from Maven:

- **Google Maven** for AndroidX libraries (Compose, Room, Navigation, Lifecycle, DataStore)
- **Maven Central** for everything else (Hilt, Koin, Retrofit, Ktor, MockK, Turbine, etc.)

Versions are cached at `~/.cache/android-gen/versions.cache` for 24 hours. Core toolchain versions (AGP, Kotlin, KSP) always use fixed compatible versions.

## Running the Tool's Own Tests

```bash
# Run all self-tests
for t in tests/test_*.sh; do bash "$t"; done
```

The tool includes 102 self-tests covering validation, version resolution, template processing, and composition logic.

## Project Structure

```
android-skeleton-generator/
  android-gen.sh          # Entry point
  lib/
    utils.sh              # Logging, validation
    prompt.sh             # Interactive prompts + CLI parsing
    versions.sh           # Maven version resolver
    generator.sh          # Template processor + project generator
    verify.sh             # Build + test verification
  templates/
    gradle/               # Version catalog, settings, wrapper
    build/                # Build files + dependency fragments
    arch/                 # Architecture-specific templates
      mvvm-clean/         # Domain + data + presentation layers
      mvi-clean/          # MVI variant with Intent/State/SideEffect
      mvvm-simple/        # Simplified flat structure
    app/                  # Manifest, Application, MainActivity, Theme, Navigation
    multimodule/          # Multi-module build files
  tests/                  # Tool self-tests
```

## License

MIT
