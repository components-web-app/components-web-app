<?php

declare(strict_types=1);

namespace App\RedisWatch;

/**
 * A CDN in front of the site that also has to forget what a flush removes.
 */
interface EdgeCache
{
    public function name(): string;

    /**
     * @throws \RuntimeException when the CDN refused or never answered
     */
    public function purgeEverything(): void;
}
