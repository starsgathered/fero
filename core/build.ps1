# build.ps1 - Cargo NDK version

# 1. Set NDK path for session
$env:ANDROID_NDK_HOME="C:\Users\TR Professional\AppData\Local\Android\Sdk\ndk\27.1.12297006"
$env:PATH="$env:ANDROID_NDK_HOME\toolchains\llvm\prebuilt\windows-x86_64\bin;$env:PATH"

# 2. List of Rust Android targets
$targets = @("aarch64-linux-android","armv7-linux-androideabi","x86_64-linux-android","i686-linux-android")

foreach ($t in $targets) {
    # Check if target is already installed
    $installed = rustup target list --installed | Select-String $t
    if (-not $installed) {
        Write-Host "Adding Rust target: $t"
        rustup target add $t
    } else {
        Write-Host "Target $t already installed, skipping."
    }
}
# 3. Multi-ABI build
cargo ndk -t armeabi-v7a -t arm64-v8a -t x86 -t x86_64 -o .\build\androidLibs build --release

Write-Host "Build finished. .so files are in .\build\androidLibs\<ABI>\"

# 4. Copy .so files to Flutter bindings
$abiMap = @{
    "armeabi-v7a" = "armeabi-v7a"
    "arm64-v8a"   = "arm64-v8a"
    "x86"         = "x86"
    "x86_64"      = "x86_64"
}

$flutterLibsDir = "..\bindings\flutter\android\app\src\main\jniLibs"

foreach ($abi in $abiMap.Keys) {
    $src = ".\build\androidLibs\$abi\*.so"
    $dest = Join-Path $flutterLibsDir $abi
    if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
    Copy-Item $src -Destination $dest -Force
    Write-Host "Copied $abi .so files to $dest"
}

Write-Host "All .so files copied to Flutter bindings."