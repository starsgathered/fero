use crate::types::enums::initial_sync_status::InitialSyncStatus;
use crate::types::func::status_callback::StatusCallback;
use async_trait::async_trait;
use std::os::raw::c_char;

#[async_trait]
pub trait InitialSyncManager: Send + Sync {
    fn status(&self) -> InitialSyncStatus;
    async fn has_initial_sync(&self, user_id: &str, feature_keys: &[String]) -> bool;
    async fn update_sync_time(&self, user_id: &str, feature: &str) -> bool;
    async fn run_initial_sync(&self, user_id: &str, feature_keys: &[String]);
    fn register_callback(&mut self, cb: StatusCallback); // trait me declare
    fn change_status(&self, status: *const c_char); // trait me declare
    fn send_example_status(&self);
    fn cancel(&self);
}
