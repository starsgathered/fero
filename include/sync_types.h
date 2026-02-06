#pragma once

#include <exception>
#include <memory>
#include <optional>
#include <string>
#include <unordered_map>

namespace fero
{

    struct SyncResult
    {
        bool success{false};
        std::exception_ptr error{nullptr};

        static SyncResult Success() { return SyncResult{true, nullptr}; }
        static SyncResult Failure(std::exception_ptr e) { return SyncResult{false, e}; }
    };

    struct SyncItem
    {
        std::string featureKey;
        std::string userId;
        std::optional<std::unordered_map<std::string, std::string>> payload;
    };

} // namespace fero
