#pragma once

#include <chrono>
#include <random>
#include <cmath>
#include <algorithm>

namespace fero
{

    using milliseconds = std::chrono::milliseconds;

    /// A pluggable backoff strategy used by sync managers when retrying.
    class BackoffStrategy
    {
    public:
        virtual ~BackoffStrategy() = default;
        virtual milliseconds nextDelay(int attempt) = 0;
    };

    class ExponentialBackoffWithJitter : public BackoffStrategy
    {
    public:
        explicit ExponentialBackoffWithJitter(milliseconds baseDelay = std::chrono::seconds(1),
                                              milliseconds maxDelay = std::chrono::seconds(30))
            : baseDelay_(baseDelay), maxDelay_(maxDelay)
        {
            std::random_device rd;
            rng_.seed(rd());
        }

        milliseconds nextDelay(int attempt) override
        {
            if (attempt <= 0)
                return milliseconds::zero();
            const double exp = std::pow(2.0, static_cast<double>(attempt));
            const long long baseMs = static_cast<long long>(baseDelay_.count());
            const long long capMs = std::min<long long>(static_cast<long long>(maxDelay_.count()), static_cast<long long>(baseMs * exp));
            if (capMs <= 0)
                return milliseconds::zero();
            std::uniform_int_distribution<long long> dist(0, capMs);
            return milliseconds(dist(rng_));
        }

    private:
        milliseconds baseDelay_;
        milliseconds maxDelay_;
        std::mt19937_64 rng_;
    };

} // namespace fero
