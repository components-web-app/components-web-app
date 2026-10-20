<?php

declare(strict_types=1);

namespace App\RedisWatch;

/**
 * Whether php's cache reaches Redis, seen through one API request: the job's own connection can't tell when only
 * php's 100ms timeouts fail (#85).
 */
interface PhpView
{
    public function check(): PhpViewResult;
}
