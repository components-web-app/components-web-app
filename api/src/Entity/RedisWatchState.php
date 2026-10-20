<?php

declare(strict_types=1);

namespace App\Entity;

use Doctrine\DBAL\Types\Types;
use Doctrine\ORM\Mapping as ORM;

/**
 * The Redis watch job's memory between runs (#85): one row, in the database because it must outlive a Redis outage.
 */
#[ORM\Entity]
class RedisWatchState
{
    public const int ID = 1;

    #[ORM\Id]
    #[ORM\Column(type: Types::SMALLINT)]
    public int $id = self::ID;

    /** Redis's run_id at the last check that reached it. */
    #[ORM\Column(type: Types::STRING, length: 64, nullable: true)]
    public ?string $redisRunId = null;

    #[ORM\Column(type: Types::DATETIMETZ_IMMUTABLE, nullable: true)]
    public ?\DateTimeImmutable $lastOkAt = null;

    /** Set while an outage lasts: the first run that saw it. */
    #[ORM\Column(type: Types::DATETIMETZ_IMMUTABLE, nullable: true)]
    public ?\DateTimeImmutable $downSince = null;

    #[ORM\Column(type: Types::TEXT, nullable: true)]
    public ?string $downReason = null;

    /** The outage email went (or there was no one to send it to), so later runs don't repeat it. */
    #[ORM\Column(type: Types::BOOLEAN)]
    public bool $downNotified = false;

    /** Redis was flushed but the CDN purge failed: the next run retries only the CDN. */
    #[ORM\Column(type: Types::BOOLEAN)]
    public bool $edgePurgePending = false;

    #[ORM\Column(type: Types::DATETIMETZ_IMMUTABLE, nullable: true)]
    public ?\DateTimeImmutable $checkedAt = null;
}
