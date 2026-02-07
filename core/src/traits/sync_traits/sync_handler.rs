use std::pin::Pin;
use std::future::Future;

pub trait SyncHandler: Send + Sync {
    fn key(&self) -> &str;
    fn run(&self, user_id: &str) -> Pin<Box<dyn Future<Output = Result<(), String>> + Send>>;
}
