use crate::traits::sync_traits::backoff_strategy::BackoffStrategy;
use std::time::Duration;

pub struct FixedBackoff {
    pub delay: Duration,
}

impl BackoffStrategy for FixedBackoff {
    fn next_delay(&self, _attempt: u32) -> Duration {
        self.delay
    }
}
