# fero — scalable repo skeleton with C++ core and Flutter FFI binding

This repository demonstrates a scalable folder layout (inspired by large projects
such as TensorFlow and OpenCV) and contains a tiny C++ core library that exposes
a simple function returning numbers 1..10. A Flutter package in `bindings/flutter`
provides a Dart FFI wrapper and an example Flutter app that calls the native library.

Structure (important parts):

- `core/` — C++ core library (headers, sources, CMake)
- `bindings/flutter/` — Flutter package that calls the native library via FFI
- `bindings/...` — placeholder for other language/platform bindings (web, node, android, ios, etc.)
- `third_party/`, `tools/`, `docs/`, `examples/` — places for growth

Build the native library (examples)

Windows (PowerShell, using MSVC and CMake):

```powershell
mkdir build; cd build
cmake -G "Visual Studio 16 2019" ..
cmake --build . --config Release
```

The produced shared library will be placed in `build/lib/` (e.g. `core_native.dll`).

Linux (g++ + CMake):

```bash
mkdir build; cd build
cmake ..
cmake --build .
```

Or compile quickly without CMake (Linux/macOS):

```bash
g++ -shared -fPIC -o libcore_native.so core/src/core.cpp -Icore/include
```

Or on Windows with MinGW (quick):

```powershell
g++ -shared -o core_native.dll core/src/core.cpp -Icore/include -Wl,--out-implib,libcore_native.a
```

Using the Flutter example

- Build the native library for your target platform and place the produced shared library
  next to the Flutter executable or in the runner's expected library search path.
- From `bindings/flutter/example`, run `flutter pub get` and then `flutter run` (target your
  desired platform). The example app will attempt to load `core_native.dll` (Windows),
  `libcore_native.so` (Linux), or `libcore_native.dylib` (macOS).

Notes and next steps

- This is a minimal example focused on demonstrating the pattern. For production:
  - Add proper symbol export/visibility controls for each platform.
  - Add CI build scripts to produce platform-specific binaries and to publish bindings.
  - Add more bindings (e.g., Node, WebAssembly, Android NDK `.so`, iOS `.framework`).
