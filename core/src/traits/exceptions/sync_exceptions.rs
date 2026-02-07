use crate::traits::exceptions::base::SyncException;
use std::fmt;

#[derive(Debug)]
pub struct SyncAlreadyRunningException {
    pub message: String,
}

#[derive(Debug)]
pub struct HandlerNotFoundException {
    pub message: String,
}

#[derive(Debug)]
pub struct InitialSyncFailedException {
    pub message: String,
}

#[derive(Debug)]
pub struct SyncFailedException {
    pub message: String,
}

#[derive(Debug)]
pub struct MaxRetriesExceededException {
    pub message: String,
}

// Display impl for all structs
macro_rules! impl_display {
    ($($t:ty),*) => {
        $(impl fmt::Display for $t {
            fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
                write!(f, "{}: {}", std::any::type_name::<$t>(), self.message)
            }
        })*
    };
}

impl_display!(
    SyncAlreadyRunningException,
    HandlerNotFoundException,
    InitialSyncFailedException,
    SyncFailedException,
    MaxRetriesExceededException
);

// Impl trait
impl SyncException for SyncAlreadyRunningException {}
impl SyncException for HandlerNotFoundException {}
impl SyncException for InitialSyncFailedException {}
impl SyncException for SyncFailedException {}
impl SyncException for MaxRetriesExceededException {}
