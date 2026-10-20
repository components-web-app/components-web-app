<?php

declare(strict_types=1);

namespace App\RedisWatch;

interface Notifier
{
    public const string SENT = 'sent';
    public const string NO_RECIPIENTS = 'no-recipients';
    public const string FAILED = 'failed';

    /**
     * @return self::SENT|self::NO_RECIPIENTS|self::FAILED
     */
    public function send(string $subject, string $body): string;
}
