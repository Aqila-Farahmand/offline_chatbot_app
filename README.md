# MedicoAI – Offline Chatbot App

MedicoAI is a cross-platform Flutter application that runs a Large Language Model **completely on-device**.  
It offers an AI-powered chat experience **without requiring an internet connection**, making it ideal for private or offline scenarios (e.g. remote clinics, airplanes, or poor-connectivity environments).

**Disclaimer:** MedicoAI is **not** a substitute for professional medical advice, diagnosis, or treatment. Always consult a qualified health-care provider with any questions you may have.

---

## Features

- **Fully offline inference** powered by [llama.cpp](https://github.com/ggerganov/llama.cpp).
- **Multi-platform:** Android, iOS, macOS, Windows, Linux (desktop & mobile).  
  _Web builds are supported but fall back to a cloud model or placeholder because WebAssembly cannot access native binaries._
- **Model manager** – detect, add, and switch between local `.gguf` models.
- **Firebase authentication** (email / Google) to sync profiles while keeping inference on-device.
- Modern Flutter UI with **Material 3** styling, dark mode, and responsive layouts.
- Reusable chat components (`ChatMessage`, `ChatInput`, etc.) and state management with **Provider**.

---

## Project Structure (key folders)

```
lib/
├── main.dart               # App entry-point & routing
├── screens/                # UI screens (chat, login)
├── services/               # Business logic (LLMService, ModelManager, ...)
├── widgets/                # Re-usable UI components
├── utils/                  # Helper utilities
└── models/ & constants/    # Data models and constants
macos/ | windows/ | linux/   # Desktop runner sources & llama binaries
assets/models/              # Optional pre-bundled .gguf models
```

---

## Prerequisites

1. **Flutter ≥ 3.16** with the desired platform SDKs installed (`flutter doctor`).
2. **Xcode** (latest version recommended) is required for building and running on macOS and iOS. Install from the Mac App Store and ensure you have agreed to the license by running `sudo xcodebuild -license`.
3. **Note on Apple Development Certificates**, For local development and testing on simulators or your own connected Apple devices, a paid Apple Development Certificate is generally NOT required. Xcode allows you to sign apps with your free Apple ID. You can manage your Apple ID in Xcode under `Xcode > Settings (or Preferences) > Accounts`. A paid Apple Developer Program membership is only necessary for distributing your app via the App Store, TestFlight, or for advanced team provisioning.

4. A **compiled `llama.cpp` binary** (`llama-cli`) for each native platform you intend to target.  
   • macOS: provided under `macos/Runner/Resources/llama/`.  
   • Others: drop the binary & required `.dll/.so/.dylib` files in the equivalent `.../Resources/llama/` directory.
5. One or more **GGUF models** (e.g. `llama-2-7b.Q4_K_M.gguf`). Place them in `assets/models/` (bundled) **or** allow the app to download/locate them at runtime.
6. `firebase_options.dart` created via `flutterfire configure` _or_ copy your Google-service files into each platform directory (`GoogleService-Info.plist`, `google-services.json`).

## Connectivity Notes

- **First-time login (or re-login after a token expiry / manual sign-out) requires an active internet connection** so that Firebase Authentication can verify user credentials.
- Ensure you have **deployed your Firebase project (Authentication + Firestore/Database rules)** before distributing the app. Credentials are fetched once, after which **all chat generation happens completely offline** — no prompts or model weights leave the device.

---

## Running the App (development)

Clone & fetch dependencies:

```bash
flutter pub get            # install Dart/Flutter packages
```

(Optional) On iOS/macOS install CocoaPods:

```bash
cd ios && pod install && cd ..
```

Launch the app on any connected device/emulator:

```bash
flutter run -d macos     # or -d android / -d ios / -d windows / -d linux
```

During the first launch the app will:

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

# Windows
flutter build windows --release
```

> Make sure the `llama-cli` executable and its accompanying libraries are
> present in the platform’s `Resources/llama` (copied automatically by
> `macos/copy_llama_cli.sh` for macOS). Repeat the same pattern for other
> platforms if necessary.

---

## Extending / Customising

• **Swap models:** Add any `.gguf` file to the application-support _models_ folder or use the in-app _Add model_ flow (to be implemented).  
• **Temperature / Top-p:** Modify the arguments passed in `LLMService.generateResponse()` to tune creativity.  
• **Replace auth:** Don’t want Firebase? Replace `FirebaseAuth` with your preferred auth provider or disable login gating.

---

## License

This project is licensed under the [Apache License 2.0](LICENSE).
