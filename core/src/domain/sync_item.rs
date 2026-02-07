// src/domain/sync_item.rs
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct SyncItem {
    pub feature_key: String,
    pub user_id: String,
    pub payload: Option<HashMap<String, String>>,
}
