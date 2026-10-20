<?php

declare(strict_types=1);

namespace App\RedisWatch;

final class RedisWatchOutcome
{
    /** @var list<string> */
    public array $lines = [];

    public bool $failed = false;

    public function say(string $line): void
    {
        $this->lines[] = $line;
    }

    public function fail(string $line): void
    {
        $this->lines[] = $line;
        $this->failed = true;
    }
}
