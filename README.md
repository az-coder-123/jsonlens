# jsonlens 🔎📁

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

**JSONLens** — A professional Flutter application for analyzing, formatting, and exploring JSON (Dark Mode by default).

## 🚀 Key Features
- Display and format JSON using 2-space indentation
- Real-time validation with descriptive error messages (line number and reason)
- Syntax highlighting with JetBrains Mono font
- Expandable/collapsible JSON tree view
- Toolbar: Format, Minify, Clear, Copy, Paste
- Validation indicator: Valid (green) / Invalid (red)

## 🔒 Privacy & Offline-first
- **Local-first operation:** The app runs entirely locally and does not require a network connection to perform JSON editing, validation, formatting, or tree browsing.
- **Network use is limited:** The app only uses the network to check for a *new app version* (fetching a small metadata record). This check is **cached** (default TTL 1 hour) to avoid frequent requests.
- **No tracking / no telemetry:** JSONLens does **not** collect analytics or tracking data. There is no background data tracking or user behavior analytics sent anywhere by default.
- **No access to personal files:** The app does not read or upload user files, directories, or other personal data on the device; clipboard operations (copy/paste) remain local to the OS clipboard.

## 🧩 Technology & Libraries
- Flutter
- State management: Riverpod (`flutter_riverpod`)
- Syntax highlighting: `flutter_highlight`
- Font: `google_fonts` (JetBrains Mono)
- JSON tree view: `flutter_json_view`
- Clipboard utilities: `flutter/services`

## 🛠️ Requirements
- Flutter SDK (stable)
- For iOS/macOS builds: macOS with Xcode and CocoaPods
- For Windows builds: Visual Studio (Desktop development workload) and required toolchain
- For Linux builds: standard desktop toolchain (GCC, etc.)

## ⚡ Quick Start
1. Install dependencies:

```bash
flutter pub get
```

2. Run the app on a device or emulator:

```bash
flutter run
```

3. Run tests:

```bash
flutter test
```

4. Format source code:

```bash
dart format .
```

---

## 🧰 Build — Debug & Release (by platform)

> Note: Flutter supports `debug`, `profile`, and `release` build modes.

### Android
- Run on a connected device or emulator:

```bash
flutter run -d <device-id>
```

- Build debug APK:

```bash
flutter build apk --debug
```

- Build release APK:

```bash
flutter build apk --release
```

- Build Android App Bundle (recommended for Play Store):

```bash
flutter build appbundle --release
```

- Install APK to a device using ADB:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

### iOS (requires macOS + Xcode)
- Run on a connected device or simulator:

```bash
flutter run -d <device-id>
```

- Build iOS app (Xcode project):

```bash
flutter build ios --release
```

- Build IPA for distribution:

```bash
flutter build ipa --export-options-plist=path/to/ExportOptions.plist
```

> Note: App Store distribution requires proper signing, provisioning profiles, and Xcode archiving.

---

### macOS
- Run in debug:

```bash
flutter run -d macos
```

- Build release:

```bash
flutter build macos --release
```

> Note: Code signing and notarization may be required for distribution.

---

### Windows
- Run in debug:

```bash
flutter run -d windows
```

- Build release:

```bash
flutter build windows --release
```

> Note: Consider creating an installer (MSIX, Inno Setup, NSIS, etc.) for user-friendly distribution.

---

### Linux
- Run in debug:

```bash
flutter run -d linux
```

- Build release:

```bash
flutter build linux --release
```

> Note: Package the app as `.deb`, `.rpm`, or other distro-specific formats for distribution.

---

## 💡 Development Tips
- Use profile mode to evaluate performance:

```bash
flutter run --profile
```

- Build for specific flavors or target platforms using `--flavor` and `--target-platform` as needed.

## ✅ Contribution Guidelines
- Follow coding standards described in `AGENTS.md`.
- Write unit and widget tests for new features.
- Open clear pull requests with descriptions and screenshots when UI changes occur.

## 📖 License
This project is licensed under the **MIT License** — see the [LICENSE](./LICENSE) file for details.
