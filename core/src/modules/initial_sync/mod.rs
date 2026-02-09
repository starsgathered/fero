use std::os::raw::c_int;

/// Dart callback type
type DartCallback = extern "C" fn(c_int);

/// Store Dart callback globally
static mut DART_CALLBACK: Option<DartCallback> = None;

/// Register Dart callback
#[no_mangle]
pub extern "C" fn call_dart(callback: DartCallback) {
    unsafe {
        DART_CALLBACK = Some(callback);
    }
}

/// Example: Rust generates numbers and calls Dart
#[no_mangle]
pub extern "C" fn rust_generate_numbers() {
    unsafe {
        if let Some(cb) = DART_CALLBACK {
            for i in 0..5 {
                cb(i); // Call Dart static function
            }
        }
    }
}
