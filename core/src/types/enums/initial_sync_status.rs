// Enums used across the crate

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum InitialSyncStatus {
    NotStarted,
    Running,
    Completed,
    Failed,
    Cancelled,
}
