use std::time::Duration;

pub trait BackoffStrategy {
    fn next_delay(&self, attempt: u32) -> Duration;
}
