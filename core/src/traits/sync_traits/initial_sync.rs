use crate::types::enums::initial_sync_status::InitialSyncStatus;
use async_trait::async_trait;

#[async_trait]
pub trait InitialSyncManager: Send + Sync {
    fn status(&self) -> InitialSyncStatus;

    async fn has_initial_sync(&self, user_id: &str, feature_keys: &[String]) -> bool;

    async fn run_initial_sync(&self, user_id: &str, feature_keys: &[String]);

    fn cancel(&self);
}
