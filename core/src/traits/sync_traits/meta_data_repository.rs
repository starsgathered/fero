use chrono::DateTime;
use chrono::Utc;
use std::future::Future;
use std::pin::Pin;

pub trait SyncMetadataRepository: Send + Sync {
    fn get_last_sync_time(
        &self,
        feature_key: &str,
        user_id: &str,
    ) -> Pin<Box<dyn Future<Output = Option<DateTime<Utc>>> + Send>>;

    fn update_sync_time(
        &self,
        feature_key: &str,
        user_id: &str,
        time: DateTime<Utc>,
    ) -> Pin<Box<dyn Future<Output = ()> + Send>>;

    fn has_all(
        &self,
        user_id: &str,
        feature_keys: &[String],
    ) -> Pin<Box<dyn Future<Output = bool> + Send>>;
}
