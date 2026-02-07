use crate::traits::sync_traits::{
    backoff_strategy::BackoffStrategy, initial_sync::InitialSyncManager,
    meta_data_repository::SyncMetadataRepository,
};
use crate::types::enums::initial_sync_status::InitialSyncStatus;
use async_trait::async_trait;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::Duration;

pub struct InitialSyncManagerImpl<H> {
    handlers: Arc<HashMap<String, H>>,
    backoff: Arc<dyn BackoffStrategy + Send + Sync>,
    max_retries: u32,
    metadata_repo: Arc<dyn SyncMetadataRepository>,
    status: Arc<Mutex<InitialSyncStatus>>,
}

impl<H> InitialSyncManagerImpl<H> {
    pub fn new(
        handlers: HashMap<String, H>,
        metadata_repo: Arc<dyn SyncMetadataRepository>,
        backoff_strategy: Option<Arc<dyn BackoffStrategy + Send + Sync>>,
        max_retries: u32,
    ) -> Self {
        Self {
            handlers: Arc::new(handlers), // Immutable map like Dart's Map.unmodifiable
            metadata_repo,
            backoff: backoff_strategy.unwrap_or_else(|| {
                Arc::new(
                    crate::common::backoff_strategies::exponential::ExponentialBackoff {
                        base: Duration::from_secs(1),
                        max: Duration::from_secs(30),
                    },
                )
            }),
            max_retries,
            status: Arc::new(Mutex::new(InitialSyncStatus::NotStarted)),
        }
    }
}

#[async_trait]
impl<H> InitialSyncManager for InitialSyncManagerImpl<H>
where
    H: Send + Sync,
{
    fn status(&self) -> InitialSyncStatus {
        let status = self.status.lock().unwrap();
        *status
    }

    async fn has_initial_sync(&self, _user_id: &str, _feature_keys: &[String]) -> bool {
        self.metadata_repo.has_all(_user_id, _feature_keys).await
    }

    async fn run_initial_sync(&self, _user_id: &str, _feature_keys: &[String]) {
        let mut status = self.status.lock().unwrap();
        *status = InitialSyncStatus::Running;
        drop(status);

        // TODO: implement actual sync logic using handlers and backoff

        let mut status = self.status.lock().unwrap();
        *status = InitialSyncStatus::Completed;
    }

    fn cancel(&self) {
        let mut status = self.status.lock().unwrap();
        *status = InitialSyncStatus::Cancelled;
    }
}
