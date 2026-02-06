#pragma once

namespace fero
{

    /// Status of the one-time initial sync process.
    enum class InitialSyncStatus
    {
        NotStarted,
        Running,
        Completed,
        Failed,
        Cancelled
    };

    inline const char *to_string(InitialSyncStatus s)
    {
        switch (s)
        {
        case InitialSyncStatus::NotStarted:
            return "NotStarted";
        case InitialSyncStatus::Running:
            return "Running";
        case InitialSyncStatus::Completed:
            return "Completed";
        case InitialSyncStatus::Failed:
            return "Failed";
        case InitialSyncStatus::Cancelled:
            return "Cancelled";
        default:
            return "Unknown";
        }
    }

} // namespace fero
