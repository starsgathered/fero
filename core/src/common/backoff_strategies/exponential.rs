use crate::traits::sync_traits::backoff_strategy::BackoffStrategy;
use std::time::Duration;

pub struct ExponentialBackoff {
    pub base: Duration,
    pub max: Duration,
}

impl BackoffStrategy for ExponentialBackoff {
    fn next_delay(&self, attempt: u32) -> Duration {
        let millis_u128 = self.base.as_millis() * 2u128.pow(attempt.saturating_sub(1));
        let millis = millis_u128.min(self.max.as_millis()) as u64;
        Duration::from_millis(millis)
    }
}
