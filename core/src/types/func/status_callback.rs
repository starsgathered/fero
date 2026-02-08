use std::os::raw::c_char;

pub type StatusCallback = extern "C" fn(status: *const c_char);
