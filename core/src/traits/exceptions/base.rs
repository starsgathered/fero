use std::fmt;

pub trait SyncException: fmt::Debug + fmt::Display + Send + Sync {}
