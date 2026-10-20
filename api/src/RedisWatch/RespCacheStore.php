<?php

declare(strict_types=1);

namespace App\RedisWatch;

final class RespCacheStore implements CacheStore
{
    public function __construct(
        private readonly string $address,
        private readonly string $password,
        private readonly float $timeout = 2.0,
    ) {
    }

    /**
     * From Souin's store block (CADDY_CACHE_STORAGE, the chart's cwa.scaled.cacheStorage), so the job checks exactly
     * the Redis php uses; null when the block names no Redis address.
     */
    public static function fromSouinStorage(string $storage, float $timeout): ?self
    {
        if (!preg_match('/^\s*redis\s*\{/', $storage) || !preg_match('/^\s*Addrs\s+(\S+)/m', $storage, $address)) {
            return null;
        }
        $password = preg_match('/^\s*Password\s+(\S+)/m', $storage, $match) ? $match[1] : '';

        return new self($address[1], $password, $timeout);
    }

    public function password(): string
    {
        return $this->password;
    }

    public function runId(): string
    {
        $info = $this->run('INFO', 'server');
        if (\is_string($info) && preg_match('/^run_id:(\w+)/m', $info, $match)) {
            return $match[1];
        }

        throw new RedisUnavailable('Redis sent no run_id');
    }

    public function flush(): void
    {
        // Souin's flush deletes every key (DeleteMany(".+") plus the SURROGATE_ index), and only Souin uses this
        // Redis. ASYNC frees memory in the background, so php's 100ms timeouts don't trip meanwhile.
        $this->run('FLUSHDB', 'ASYNC');
    }

    /**
     * @return string|int|list<mixed>|null
     */
    private function run(string ...$command): string|int|array|null
    {
        $connection = RespConnection::open($this->address, $this->password, $this->timeout);
        try {
            return $connection->command(...$command);
        } finally {
            $connection->close();
        }
    }
}
