use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};
use std::sync::{mpsc, Mutex, OnceLock};

extern "C" {
    fn __android_log_print(priority: c_int, tag: *const c_char, fmt: *const c_char, ...) -> c_int;
}

const ANDROID_LOG_INFO: i32 = 4;

macro_rules! log_android {
    ($tag:expr, $msg:expr) => {
        unsafe {
            let tag_c = CString::new($tag).unwrap();
            let msg_c = CString::new($msg).unwrap();
            __android_log_print(ANDROID_LOG_INFO, tag_c.as_ptr(), msg_c.as_ptr());
        }
    };
}

type DartCallback = extern "C" fn(handler_id: *const c_char, user_id: *const c_char);

// Global map: handler_id → sender
static SENDERS: OnceLock<Mutex<HashMap<String, mpsc::Sender<bool>>>> = OnceLock::new();

fn senders() -> &'static Mutex<HashMap<String, mpsc::Sender<bool>>> {
    SENDERS.get_or_init(|| Mutex::new(HashMap::new()))
}

#[no_mangle]
pub extern "C" fn call_rust(
    handler_id: *const c_char,
    user_id: *const c_char,
    callback: DartCallback,
) {
    log_android!("RustSync", "Hello from Rust!");

    let handler_str = unsafe {
        CStr::from_ptr(handler_id)
            .to_str()
            .unwrap_or_default()
            .to_string()
    };
    let user_str = unsafe {
        CStr::from_ptr(user_id)
            .to_str()
            .unwrap_or_default()
            .to_string()
    };

    let (tx, rx) = std::sync::mpsc::channel();
    SENDERS
        .get_or_init(|| Mutex::new(HashMap::new()))
        .lock()
        .unwrap()
        .insert(handler_str.clone(), tx);

    // Spawn thread for retries
    std::thread::spawn(move || {
        let max_retries = 5;
        for attempt in 1..=max_retries {
            let handler_c = CString::new(handler_str.clone()).unwrap();
            let user_c = CString::new(user_str.clone()).unwrap();
            callback(handler_c.as_ptr(), user_c.as_ptr());

            match rx.recv() {
                Ok(true) => break,
                Ok(false) => println!("Retry {}", attempt),
                Err(_) => break,
            }
        }

        SENDERS.get().unwrap().lock().unwrap().remove(&handler_str);
    });
}

#[no_mangle]
pub extern "C" fn report_sync_result(handler_id: *const c_char, success: bool) {
    // Convert raw pointer to Rust string
    let handler_str = unsafe {
        CStr::from_ptr(handler_id)
            .to_str()
            .unwrap_or_default()
            .to_string()
    };

    if let Some(sender) = senders().lock().unwrap().remove(&handler_str) {
        let _ = sender.send(success);
    }
}
