use crate::traits::exceptions::sync_exceptions::{
    HandlerNotFoundException, MaxRetriesExceededException, SyncAlreadyRunningException,
};
use crate::traits::sync_traits::{
    backoff_strategy::BackoffStrategy, initial_sync::InitialSyncManager,
    meta_data_repository::SyncMetadataRepository, sync_handler::SyncHandler
};
use crate::types::enums::initial_sync_status::InitialSyncStatus;
use async_trait::async_trait;
use std::collections::HashMap;
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};
use std::time::Duration;

pub struct InitialSyncManagerImpl {
    metadata_repo: Arc<dyn SyncMetadataRepository>,
    handlers: Arc<HashMap<String, Arc<dyn SyncHandler>>>,
    backoff: Arc<dyn BackoffStrategy>,
    max_retries: u32,
    status: Arc<Mutex<InitialSyncStatus>>,
    is_running: AtomicBool,
    is_cancelled: AtomicBool,
}

impl InitialSyncManagerImpl {
    pub fn new(
        metadata_repo: Arc<dyn SyncMetadataRepository>,
        handlers: HashMap<String, Arc<dyn SyncHandler>>,
        backoff: Arc<dyn BackoffStrategy>,
        max_retries: u32,
    ) -> Self {
        Self {
            metadata_repo,
            handlers: Arc::new(handlers),
            backoff,
            max_retries,
            status: Arc::new(Mutex::new(InitialSyncStatus::NotStarted)),
            is_running: AtomicBool::new(false),
            is_cancelled: AtomicBool::new(false),
        }
    }

    /// Demo helper: sets status to Running, invokes the provided
    /// `on_status_changed` callback, waits ~2 seconds, then sets Completed
    /// (or Cancelled if cancellation was requested) and invokes the callback.
    pub fn demo_initial_sync<F>(&self, _user_id: &str, _feature_keys: &[String], on_status_changed: F)
    where
        F: Fn(InitialSyncStatus),
    {
        if self
            .is_running
            .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
            .is_err()
        {
            panic!(
                "{}",
                SyncAlreadyRunningException {
                    message: "Initial sync already running".into()
                }
            );
        }

        *self.status.lock().unwrap() = InitialSyncStatus::Running;
        on_status_changed(InitialSyncStatus::Running);

        std::thread::sleep(Duration::from_secs(2));

        if self.is_cancelled.load(Ordering::SeqCst) {
            *self.status.lock().unwrap() = InitialSyncStatus::Cancelled;
            on_status_changed(InitialSyncStatus::Cancelled);
            self.is_running.store(false, Ordering::SeqCst);
            return;
        }

        *self.status.lock().unwrap() = InitialSyncStatus::Completed;
        on_status_changed(InitialSyncStatus::Completed);
        self.is_running.store(false, Ordering::SeqCst);
    }
}

#[async_trait]
impl InitialSyncManager for InitialSyncManagerImpl {
    fn status(&self) -> InitialSyncStatus {
        *self.status.lock().unwrap()
    }

    async fn has_initial_sync(&self, user_id: &str, feature_keys: &[String]) -> bool {
        self.metadata_repo.has_all(user_id, feature_keys).await
    }

    async fn run_initial_sync(&self, user_id: &str, feature_keys: &[String]) {
        if self
            .is_running
            .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
            .is_err()
        {
            panic!(
                "{}",
                SyncAlreadyRunningException {
                    message: "Initial sync already running".into()
                }
            );
        }

        *self.status.lock().unwrap() = InitialSyncStatus::Running;

        for feature_key in feature_keys {
            if self.is_cancelled.load(Ordering::SeqCst) {
                *self.status.lock().unwrap() = InitialSyncStatus::Cancelled;
                self.is_running.store(false, Ordering::SeqCst);
                return;
            }

            let handler = self.handlers.get(feature_key).unwrap_or_else(|| {
                panic!(
                    "{}",
                    HandlerNotFoundException {
                        message: format!("Handler not found for {}", feature_key)
                    }
                )
            });

            let mut attempt = 0;
            loop {
                if self.is_cancelled.load(Ordering::SeqCst) {
                    *self.status.lock().unwrap() = InitialSyncStatus::Cancelled;
                    self.is_running.store(false, Ordering::SeqCst);
                    return;
                }

                match handler.run(user_id).await {
                    Ok(_) => {
                        self.metadata_repo
                            .update_sync_time(feature_key, user_id, chrono::Utc::now())
                            .await;
                        break;
                    }
                    Err(_) if attempt < self.max_retries => {
                        let delay: Duration = self.backoff.next_delay(attempt);
                        std::thread::sleep(delay);
                        attempt += 1;
                    }
                    Err(_) => {
                        *self.status.lock().unwrap() = InitialSyncStatus::Failed;
                        self.is_running.store(false, Ordering::SeqCst);
                        panic!(
                            "{}",
                            MaxRetriesExceededException {
                                message: format!("Max retries exceeded for {}", feature_key)
                            }
                        );
                    }
                }
            }
        }

        *self.status.lock().unwrap() = InitialSyncStatus::Completed;
        self.is_running.store(false, Ordering::SeqCst);
    }

    fn cancel(&self) {
        self.is_cancelled.store(true, Ordering::SeqCst);
    }
}
