use std::time::Duration;

use crate::{
    common::backoff_strategies::{exponential::ExponentialBackoff, fixed::FixedBackoff},
    traits::sync_traits::backoff_strategy::BackoffStrategy,
};

#[repr(u8)]
pub enum BackoffType {
    Fixed,
    Exponential,
}

pub struct BackoffConfig {
    pub strategy: BackoffType,
    pub base: u64, // millis
    pub max: u64,  // millis
}

impl BackoffConfig {
    /// Global helper: create BackoffConfig from raw params
    pub fn from_raw(backoff_type: u8, base: u64, max: u64) -> Self {
        let strategy = match backoff_type {
            0 => BackoffType::Fixed,
            1 => BackoffType::Exponential,
            _ => BackoffType::Fixed,
        };
        BackoffConfig {
            strategy,
            base,
            max,
        }
    }
    pub fn to_strategy(&self) -> Box<dyn BackoffStrategy> {
        match self.strategy {
            BackoffType::Fixed => Box::new(FixedBackoff {
                delay: Duration::from_millis(self.base),
            }),
            BackoffType::Exponential => Box::new(ExponentialBackoff {
                base: Duration::from_millis(self.base),
                max: Duration::from_millis(self.max),
            }),
        }
    }
}
