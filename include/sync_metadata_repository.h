#pragma once

#include <chrono>
#include <future>
#include <optional>
#include <string>
#include <vector>

namespace fero
{

    /// DB-agnostic metadata repository used to track last-sync timestamps.
    class SyncMetadataRepository
    {
    public:
        virtual ~SyncMetadataRepository() = default;

        /// Return the last sync time for `featureKey` and `userId`, or empty optional if none.
        virtual std::future<std::optional<std::chrono::system_clock::time_point>>
        getLastSyncTime(const std::string &featureKey, const std::string &userId) = 0;

        /// Update the last sync time for `featureKey` and `userId`.
        virtual std::future<void>
        updateSyncTime(const std::string &featureKey, const std::string &userId,
                       const std::chrono::system_clock::time_point &time) = 0;

        /// Return true if all `featureKeys` have recorded sync times for `userId`.
        virtual std::future<bool>
        hasAll(const std::string &userId, const std::vector<std::string> &featureKeys) = 0;
    };

} // namespace fero
