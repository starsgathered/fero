#pragma once

#include "sync_types.h"
#include <future>

namespace fero
{

    class SyncHandler
    {
    public:
        virtual ~SyncHandler() = default;
        virtual std::future<SyncResult> handle(const SyncItem &item) = 0;
    };

} // namespace fero
