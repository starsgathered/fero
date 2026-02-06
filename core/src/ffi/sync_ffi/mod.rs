// Minimal FFI surface for sync functionality

#[no_mangle]
pub extern "C" fn fero_sync_version() -> *const u8 {
    b"0.1.0\0".as_ptr()
}
