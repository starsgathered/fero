// Minimal FFI surface for initial sync (thin layer)

use std::ffi::{CStr};
use std::os::raw::c_char;
use std::sync::atomic::{AtomicU32, Ordering};

#[no_mangle]
pub extern "C" fn fero_sync_version() -> *const u8 {
    b"0.1.0\0".as_ptr()
}

#[repr(u32)]
pub enum InitialSyncStatus {
    NotStarted = 0,
    Running = 1,
    Completed = 2,
    Cancelled = 3,
}

static STATUS: AtomicU32 = AtomicU32::new(InitialSyncStatus::NotStarted as u32);

#[no_mangle]
pub extern "C" fn fero_initial_sync_get_status() -> u32 {
    STATUS.load(Ordering::SeqCst)
}

/// has_initial_sync(user_id: *const c_char, feature_keys_json: *const c_char) -> u8 (0/1)
#[no_mangle]
pub extern "C" fn fero_initial_sync_has_initial_sync(
    user_id: *const c_char,
    _feature_keys_json: *const c_char,
) -> u8 {
    if user_id.is_null() {
        return 0;
    }

    // Thin implementation: currently delegates to metadata check is not wired, return 0
    // Keep signature simple for Dart: accept JSON string for feature keys.
    0
}

/// run_initial_sync(user_id: *const c_char, feature_keys_json: *const c_char)
#[no_mangle]
pub extern "C" fn fero_initial_sync_run_initial_sync(
    user_id: *const c_char,
    _feature_keys_json: *const c_char,
) {
    if user_id.is_null() {
        return;
    }

    STATUS.store(InitialSyncStatus::Running as u32, Ordering::SeqCst);

    // Simulate async work: spawn a thread and mark completed after a short delay.
    std::thread::spawn(|| {
        std::thread::sleep(std::time::Duration::from_secs(1));
        STATUS.store(InitialSyncStatus::Completed as u32, Ordering::SeqCst);
    });
}

#[no_mangle]
pub extern "C" fn fero_initial_sync_cancel() {
    STATUS.store(InitialSyncStatus::Cancelled as u32, Ordering::SeqCst);
}

