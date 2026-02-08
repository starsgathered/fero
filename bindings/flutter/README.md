# Fero Flutter bindings - example

This folder contains the Flutter bindings for the Fero sync SDK and a small example app.

Quick steps to run the example (Android):

1. Build the Rust native library for Android (example using cargo):

```powershell
# build for arm64 (example)
cargo build --release --target aarch64-linux-android
```

2. Copy the produced `libcore.so` into your Android app `jniLibs` for each ABI you build for, for example:

```
android/app/src/main/jniLibs/arm64-v8a/libcore.so
```

3. Run the Flutter app:

```bash
flutter run
```

Notes:
- The Dart `InitialSyncManager` loads `libcore.so` on Android. Ensure the library name and placement matches.
- For iOS/macOS/Windows adjust the native library build and `DynamicLibrary` open logic in `initial_sync_manager.dart`.
# Fero Flutter
