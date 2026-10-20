<?php

declare(strict_types=1);

namespace App\RedisWatch;

final readonly class PhpViewResult
{
    public const string OK = 'ok';
    public const string REDIS_ERROR = 'redis-error';
    public const string UNKNOWN = 'unknown';

    private function __construct(public string $status, public string $detail)
    {
    }

    public static function ok(string $detail): self
    {
        return new self(self::OK, $detail);
    }

    public static function redisError(string $detail): self
    {
        return new self(self::REDIS_ERROR, $detail);
    }

    public static function unknown(string $detail): self
    {
        return new self(self::UNKNOWN, $detail);
    }

    /**
     * From a response's Cache-Status: a hit or a store proves php reached Redis, an insertion error that it didn't.
     */
    public static function fromCacheStatus(string $cacheStatus): self
    {
        if (str_contains($cacheStatus, '-INSERTION-ERROR')) {
            return self::redisError($cacheStatus);
        }
        $parts = array_map('trim', explode(';', $cacheStatus));
        if (\in_array('hit', $parts, true) || \in_array('stored', $parts, true)) {
            return self::ok($cacheStatus);
        }

        return self::unknown('' === $cacheStatus ? 'no Cache-Status' : $cacheStatus);
    }
}
