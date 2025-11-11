# Configuration Structure

This directory contains platform-agnostic configuration files that are accessible to **all platforms** (web, Android, iOS, macOS, Windows, Linux).

## How It Works

### Dart Configs (`lib/config/`)
- **Location**: `lib/config/*.dart`
- **Accessibility**: All platforms (compiled into the app)
- **Usage**: Imported in Dart/Flutter code
- **Examples**:
  - `path_configs.dart` - Asset paths
  - `prompt_configs.dart` - Prompt templates
  - `admin_config.dart` - Admin user lists
  - `firebase/` - Platform-specific Firebase configs

### Web-Specific JavaScript Configs (`web/config/`)
- **Location**: `web/config/config.js`
- **Accessibility**: Web only (copied to `build/web/config/` during build)
- **Usage**: Imported in JavaScript files (e.g., `web/mediapipe_text.js`)
- **Note**: Must stay in sync with `lib/config/path_configs.dart`

## Asset Structure

### Source Assets (Root Level)
- `models/` - Model files (`.gguf`, `.task`)
- `mediapipe/` - MediaPipe GenAI bundle and WASM files
- `evaluation/dataset/` - Evaluation datasets

### How Assets Are Accessed

1. **All Platforms (via `pubspec.yaml`)**:
   ```yaml
   flutter:
     assets:
       - models/
       - mediapipe/
       - mediapipe/wasm/
   ```
   - Flutter copies these to platform-specific locations during build
   - Access via `rootBundle.loadString()` or `AssetManifest.json`

2. **Web Platform**:
   - Assets copied to `build/web/assets/` during `flutter build web`
   - Accessible at `/assets/` path (e.g., `/assets/models/`, `/assets/mediapipe/`)

3. **Native Platforms** (Android, iOS, macOS, etc.):
   - Assets bundled in app bundle
   - Access via Flutter's asset system

## Build Process

1. **Flutter Build** (`flutter build web`):
   - Compiles Dart code from `lib/` → JavaScript
   - Copies `web/` directory → `build/web/` (including `web/config/`)
   - Copies assets from `pubspec.yaml` → `build/web/assets/`

2. **Firebase Hosting**:
   - Serves from `build/web/` directory
   - All configs and assets are accessible

## Keeping Configs in Sync

The JavaScript config (`web/config/config.js`) must match the Dart config (`lib/config/path_configs.dart`). Currently maintained manually - ensure both are updated when paths change.

