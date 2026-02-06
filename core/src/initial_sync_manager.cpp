#include <initial_sync_manager.h>
#include <backoff.h>

namespace fero
{

    InitialSyncManager::InitialSyncManager(
        std::unordered_map<std::string, std::shared_ptr<SyncHandler>> handlers,
        std::shared_ptr<SyncMetadataRepository> metadataRepo,
        std::unique_ptr<BackoffStrategy> backoffStrategy,
        int maxRetries) : _metadataRepo(std::move(metadataRepo)),
                          _handlers(std::move(handlers)),
                          _backoff(backoffStrategy ? std::move(backoffStrategy) : std::make_unique<ExponentialBackoffWithJitter>()),
                          _maxRetries(maxRetries)
    {
    }

    InitialSyncManager::~InitialSyncManager() = default;

} // namespace fero
