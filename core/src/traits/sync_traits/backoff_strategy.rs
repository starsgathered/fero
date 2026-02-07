use std::time::Duration;

pub trait BackoffStrategy: Send + Sync {
    fn next_delay(&self, attempt: u32) -> Duration;
}
