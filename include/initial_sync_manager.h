#pragma once

#include <initial_sync_status.h>
#include <sync_handler.h>
#include <sync_metadata_repository.h>
#include <backoff.h>

#include <memory>
#include <string>
#include <unordered_map>

namespace fero
{

    class InitialSyncManager
    {
    public:
        /// Construct an InitialSyncManager.
        ///
        /// Parameters:
        /// - `handlers`: map of featureKey -> handler (required). The map is copied and treated as read-only.
        /// - `metadataRepo`: repository used to store sync metadata (required).
        /// - `backoffStrategy`: optional backoff strategy; if null, a default ExponentialBackoffWithJitter is used.
        /// - `maxRetries`: maximum number of retries for an item (default 5).
        InitialSyncManager(
            std::unordered_map<std::string, std::shared_ptr<SyncHandler>> handlers,
            std::shared_ptr<SyncMetadataRepository> metadataRepo,
            std::unique_ptr<BackoffStrategy> backoffStrategy = nullptr,
            int maxRetries = 5);

        ~InitialSyncManager();

        // Non-copyable, movable
        InitialSyncManager(const InitialSyncManager &) = delete;
        InitialSyncManager &operator=(const InitialSyncManager &) = delete;

        /// Returns the current initial sync status.
        InitialSyncStatus status() const { return _status; }

    private:
        std::shared_ptr<SyncMetadataRepository> _metadataRepo;
        const std::unordered_map<std::string, std::shared_ptr<SyncHandler>> _handlers;
        std::unique_ptr<BackoffStrategy> _backoff;
        int _maxRetries{5};
        InitialSyncStatus _status{InitialSyncStatus::NotStarted};
    };

} // namespace fero
