# MedicoAI – Offline Chatbot App

MedicoAI is a cross-platform Flutter application that runs a large language model **completely on-device**.  
It offers an AI-powered chat experience **without requiring an internet connection**, making it ideal for private or offline scenarios (e.g., remote clinics, airplanes, or environments with poor connectivity).

**Disclaimer:** MedicoAI is **not** a substitute for professional medical advice, diagnosis, or treatment. Always consult a qualified health-care provider with any questions you may have.

---

## Features

- **Fully offline inference** powered by [llama.cpp](https://github.com/ggerganov/llama.cpp) (desktop) or MediaPipe (mobile and web).
- **Multi-platform:** Android, iOS, macOS, and web (desktop & mobile).
- **Model manager** – detect, add, and switch between local `.gguf` models.
- **Firebase authentication** (email / Google) to sync profiles while keeping inference on-device.
- Modern Flutter UI with **Material 3** styling, dark mode, and responsive layouts.
- Reusable chat components (`ChatMessage`, `ChatInput`, etc.) and state management with **Provider**.

---

## Platform Comparison

| Platform | LLM Engine | Model Format                          | Notes                                   |
| -------- | ---------- | ------------------------------------- | --------------------------------------- |
| Desktop  | llama.cpp  | .gguf                                 | Native binaries required per OS         |
| Mobile   | MediaPipe  | .task                                 | Uses `com.google.mediapipe:tasks-genai` |
| Web      | MediaPipe  | .task (model's name with -web suffix) | Uses `com.google.mediapipe:tasks-genai` |

---

## Project Structure (key folders)

```
lib/
├── main.dart               # App entry-point & routing
├── screens/                # UI screens (chat, login)
├── services/               # LLM model handling (LLMService, ModelManager, ...)
├── widgets/                # Re-usable UI components
├── utils/                  # Helper utilities
└── models/ & config/    # Data models and configs
macos/ | android / | web/   # Device runner sources
assets/models/              # Pre-bundled .gguf or .task llm models
```

---

## Desktop Implementation

1. **llama.cpp** is used for on-device LLM inference on desktop platforms (macOS, Windows, Linux). This requires native binaries and sufficient storage/compute resources.
2. Place your compiled `llama-cli` binary in the appropriate platform directory (e.g., `macos/Runner/Resources/llama/`).
3. Add one or more `.gguf` models to `assets/models/` or let the app locate them at runtime.

### Prerequisites (Desktop)

- **Flutter ≥ 3.16** with platform SDKs installed (`flutter doctor`).
- **Xcode** (latest) for macOS/iOS builds. Accept license: `sudo xcodebuild -license`.
- **llama.cpp** binary for your OS.
- **GGUF models** in `assets/models/`.

---

## Mobile Implementation

1. Integrating llama.cpp directly on mobile is impractical due to storage and compute constraints. Instead, we use **MediaPipe** for efficient on-device LLM inference on Android and iOS.
2. The LLM Inference API uses the `com.google.mediapipe:tasks-genai` library. Add this dependency to your Android app’s `build.gradle` file.
3. Models must be in `.task` format for both Android and Web applications.

### Prerequisites (Mobile)

- **Flutter ≥ 3.16** with Android/iOS SDKs.
- Add `com.google.mediapipe:tasks-genai` to your Android `build.gradle`.
- Use `.task` model files for MediaPipe.

---

## Authentication

To set up Firebase authentication:

- Generate `firebase_options.dart` via `flutterfire configure` _or_ copy your Google-service files into each platform directory (`GoogleService-Info.plist`, `google-services.json`).

---

## Connectivity Notes

- **First-time login (or re-login after a token expiry / manual sign-out) requires an active internet connection** so that Firebase Authentication can verify user credentials.
- Ensure you have **deployed your Firebase project (Authentication + Firestore/Database rules)** before distributing the app. Credentials are fetched once, after which **all chat generation happens completely offline** — no prompts or model weights leave the device.

---

## Running the App (Development)

Follow these steps to set up and run the application in a development environment.

1. Fetch Dependencies

   Navigate to the project's root directory in your terminal and install the necessary Dart and Flutter packages:

```Bash
flutter pub get
```

2. Platform-Specific Setup (iOS/macOS only)

   If you are developing for iOS or macOS, you need to install CocoaPods, which manages native dependencies for these platforms.

```Bash
cd ios && pod install && cd ..
```

Note:

If you encounter issues with pod install, ensure you have CocoaPods installed on your system (`sudo gem install cocoapods`) and that Xcode command-line tools are properly configured (xcode-select --install).

3. Launch the App

   You can launch the app on any connected device, emulator, or simulator.

- A. List Available Devices

  First, identify the available devices by running:

```Bash
flutter devices
```

This command will output a list of recognized devices with their unique identifiers (e.g., macOS, sdk gphone64 arm64, your_iphone_device_id, chrome, etc.).

- B. Run on a Specific Device

  Once you have the device ID, use the -d flag to specify your target. Replace [device_id] with the actual ID from the flutter devices output.

```Bash
flutter run -d [device_id]
```

Examples:

macOS Desktop:

```Bash
flutter run -d macos
```

Android Emulator/Device:

```Bash
flutter run -d "your deviceId" # (or your specific Android emulator/device ID)
```

iOS Simulator/Device:

```Bash
flutter run -d AAAA-BBBB-CCCC-DDDD-EEEE # (replace with your iPhone's long ID)
```

Or for a simulator:

```Bash
flutter run -d "iPhone 15 Pro Max" # (if the name is unique)
```

Tip for iOS:

- For physical iOS devices, ensure "Developer Mode" is enabled on your iPhone (iOS 16+), and you have trusted your computer. You may also need to open ios/Runner.xcworkspace in Xcode once to set up development team signing under the "Signing & Capabilities" tab for the Runner target.

Web (Chrome):

```Bash
flutter run -d chrome
```

Linux Desktop:

```Bash
flutter run -d linux
```

During the first launch, the app will:

1. Copy the bundled `llama-cli` and dynamic libraries into the app support directory (macOS example).
2. Scan `Application Support/models` for `.gguf` files and populate the **Model Selector** dialog.

Select a model and start chatting!

---

## Building Release Binaries

```bash
# Android (APK)
flutter build apk --release

# iOS (requires Xcode)
flutter build ios --release

# macOS
flutter build macos --release

# web
flutter build web --release
```

> Make sure the `llama-cli` executable and its accompanying libraries are
> present in the platform's `Resources/llama` (copied automatically by
> `macos/copy_llama_cli.sh` for macOS. Repeat the same pattern for other
> platforms if necessary.

---

## Testing Firebase Hosting Locally

To test your Flutter web app with Firebase hosting emulator:

1. **Build the Flutter web app:**

   ```bash
   flutter build web
   ```

   This creates the `build/web` directory that Firebase hosting serves.

2. **Start Firebase emulators:**

   ```bash
   firebase emulators:start
   ```

   Or to start only the hosting emulator:

   ```bash
   firebase emulators:start --only hosting
   ```

3. **Access your app:**
   - The hosting emulator will be available at `http://127.0.0.1:5019` (or the port specified in `firebase.json`)
   - The Firebase Emulator UI is available at `http://127.0.0.1:4000`

**Quick commands (using npm scripts):**

```bash
# Build web app
npm run build:web

# Start Firebase hosting emulator (after building)
npm run serve:firebase

# Build and serve in one command
npm run build:web:serve
```

**Note:** Make sure to rebuild the web app (`flutter build web`) whenever you make changes to your Flutter code, as the Firebase hosting emulator serves the static files from `build/web`.

---

## Extending / Customizing

• **Swap models:** Add any `.gguf` file to the application-support _models_ folder or use the in-app _Add model_ flow (to be implemented).  
• **Temperature / Top-p:** Modify the arguments passed in `LLMService.generateResponse()` to tune creativity.  
• **Replace auth:** Don’t want Firebase? Replace `FirebaseAuth` with your preferred auth provider or disable login gating.

---

## License

This project is licensed under the [Apache License 2.0](LICENSE).
