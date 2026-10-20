<?php

declare(strict_types=1);

namespace App\RedisWatch;

/**
 * Redis could not be reached, or refused a command. The message never carries the password.
 */
final class RedisUnavailable extends \RuntimeException
{
}
