// src/domain/sync_result.rs
use crate::traits::exceptions::base::SyncException;

#[derive(Debug)]
pub struct SyncResult {
    pub success: bool,
    pub error: Option<Box<dyn SyncException + Send + Sync>>,
}

impl SyncResult {
    pub fn success() -> Self {
        SyncResult {
            success: true,
            error: None,
        }
    }

    pub fn failure(error: Box<dyn SyncException + Send + Sync>) -> Self {
        SyncResult {
            success: false,
            error: Some(error),
        }
    }
}
