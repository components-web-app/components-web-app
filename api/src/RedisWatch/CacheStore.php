<?php

declare(strict_types=1);

namespace App\RedisWatch;

/**
 * Scaled mode's shared cache: the release's Redis, which holds nothing but Souin's entries and tag index (#85).
 */
interface CacheStore
{
    /**
     * Redis's run_id, which changes whenever Redis restarts (and so starts empty: it keeps nothing on disk).
     *
     * @throws RedisUnavailable
     */
    public function runId(): string;

    /**
     * Empties the store: what Souin's own full flush does in scaled mode.
     *
     * @throws RedisUnavailable
     */
    public function flush(): void;
}
