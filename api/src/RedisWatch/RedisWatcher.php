<?php

declare(strict_types=1);

namespace App\RedisWatch;

use App\Entity\RedisWatchState;

/**
 * One run of the Redis watch job (#85). In scaled mode, while php can't reach Redis, pages are served uncached and
 * purges are lost (Souin still answers 204), so Redis can come back holding copies an edit should have removed.
 *
 * - Down: this job can't reach Redis, or php can't store in it. Every attempt must agree, so a blip doesn't count.
 *   The first down run emails; later ones don't.
 * - Reachable again after a down run: flush Redis once, purge the CDN (it may have re-cached from a stale Redis),
 *   and email what happened. A failed flush keeps the outage open, so the next run tries again.
 * - Redis restarted between two runs that both reached it: it came back empty, so nothing is stale; email only.
 */
final class RedisWatcher
{
    /** @var \Closure(int): void */
    private \Closure $sleep;

    /**
     * @param (callable(int): void)|null $sleep
     */
    public function __construct(
        private readonly CacheStore $store,
        private readonly PhpView $php,
        private readonly Notifier $notifier,
        private readonly ?EdgeCache $edge = null,
        private readonly int $attempts = 3,
        private readonly int $attemptInterval = 2,
        ?callable $sleep = null,
    ) {
        $this->sleep = $sleep ? $sleep(...) : static function (int $seconds): void { sleep($seconds); };
    }

    public function run(RedisWatchState $state, \DateTimeImmutable $now): RedisWatchOutcome
    {
        $outcome = new RedisWatchOutcome();
        $state->checkedAt = $now;

        $runId = null;
        $reason = null;
        for ($attempt = 1; $attempt <= max(1, $this->attempts); ++$attempt) {
            if ($attempt > 1) {
                ($this->sleep)($this->attemptInterval);
            }
            [$runId, $reason, $phpOk] = $this->observe();
            if (null === $reason) {
                break;
            }
            if (null === $runId && $phpOk) {
                // php reaches Redis, so the fault is this job's own (its password, or a NetworkPolicy that leaves it out).
                $outcome->fail('php reaches Redis but this job can\'t: '.$reason);

                return $outcome;
            }
        }

        if (null !== $reason) {
            $this->down($state, $now, $reason, $outcome);

            return $outcome;
        }
        \assert(null !== $runId);

        if (null !== $state->downSince) {
            if (!$this->recover($state, $now, $outcome)) {
                return $outcome;
            }
        } elseif (null !== $state->redisRunId && $runId !== $state->redisRunId) {
            $outcome->say('Redis restarted since the last check; it started empty, so nothing is stale.');
            $this->notify($outcome, 'Redis restarted', implode("\n\n", [
                \sprintf('The cache store (Redis) restarted between %s and %s. It keeps nothing on disk, so it started empty: nothing cached is stale and nothing needed flushing.', self::time($state->lastOkAt), self::time($now)),
                'Pages were served uncached while it was down. If this keeps happening, check the Redis pod (kubectl get pods; kubectl describe pod for an OOMKilled reason) and raise CWA_CI_API_REDIS_MEMORY if it was full.',
            ]));
        } elseif ($state->edgePurgePending && null !== $this->edge) {
            if (!$this->purgeEdge($state, $outcome)) {
                $outcome->fail('The CDN purge failed again.');

                return $outcome;
            }
        }

        if (null === $state->redisRunId) {
            $outcome->say('First check: Redis is reachable.');
        } elseif ([] === $outcome->lines) {
            $outcome->say('Redis is reachable.');
        }
        $state->redisRunId = $runId;
        $state->lastOkAt = $now;

        return $outcome;
    }

    /**
     * @return array{0: ?string, 1: ?string, 2: bool} run_id (null when unreachable), why it's down (null when it isn't), php's view OK
     */
    private function observe(): array
    {
        $runId = null;
        $own = null;
        try {
            $runId = $this->store->runId();
        } catch (RedisUnavailable $e) {
            $own = $e->getMessage();
        }
        $php = $this->php->check();

        if (PhpViewResult::REDIS_ERROR === $php->status) {
            return [$runId, 'php could not store in Redis (Cache-Status: '.$php->detail.')', false];
        }
        if (null !== $own) {
            return [null, 'this job could not reach Redis ('.$own.'); php: '.$php->detail, PhpViewResult::OK === $php->status];
        }

        return [$runId, null, PhpViewResult::OK === $php->status];
    }

    private function down(RedisWatchState $state, \DateTimeImmutable $now, string $reason, RedisWatchOutcome $outcome): void
    {
        if (null === $state->downSince) {
            $state->downSince = $now;
            $state->downReason = $reason;
            $state->downNotified = false;
        }
        $outcome->say('Redis is unreachable: '.$reason);
        if ($state->downNotified) {
            $outcome->say(\sprintf('Since %s; already emailed.', self::time($state->downSince)));

            return;
        }

        $result = $this->notify($outcome, 'the cache store (Redis) is unreachable', implode("\n\n", [
            \sprintf('Since %s the site cannot reach its cache store (Redis): %s.', self::time($state->downSince), $reason),
            'The site stays up, uncached and slower. Purges sent meanwhile are lost, so edits made now may not show until the cache is flushed.',
            'Nothing to do yet: this job checks again every few minutes, and once Redis is reachable it flushes the cache and emails again. This email is not repeated.',
            'If it lasts, check the Redis pod: kubectl get pods and kubectl logs for <release>-redis; restart it, or raise CWA_CI_API_REDIS_MEMORY and deploy if it was full.',
        ]));
        $state->downNotified = Notifier::FAILED !== $result;
    }

    private function recover(RedisWatchState $state, \DateTimeImmutable $now, RedisWatchOutcome $outcome): bool
    {
        try {
            $this->store->flush();
        } catch (RedisUnavailable $e) {
            $outcome->fail('Redis is reachable again, but the flush failed: '.$e->getMessage());

            return false;
        }
        $outcome->say(\sprintf('Redis is reachable again (unreachable since %s); flushed it.', self::time($state->downSince)));

        $edgeLine = '';
        if (null !== $this->edge) {
            $edgeLine = $this->purgeEdge($state, $outcome)
                ? \sprintf('It also purged everything in %s, which may have re-cached a stale copy.', $this->edge->name())
                : \sprintf('Purging %s failed, so it may still serve stale copies; this job retries next run, or press Purge all cached data in the site settings.', $this->edge->name());
        }

        $this->notify($outcome, 'the cache store (Redis) is back; the cache was flushed', implode("\n\n", array_filter([
            \sprintf('The site could not reach its cache store (Redis) from %s (%s) until %s.', self::time($state->downSince), $state->downReason, self::time($now)),
            'Purges sent in that time were lost, so this job flushed the whole cache once: edits made meanwhile now show. Pages are cached again as visitors request them.',
            $edgeLine,
        ])));

        $state->downSince = null;
        $state->downReason = null;
        $state->downNotified = false;

        return true;
    }

    private function purgeEdge(RedisWatchState $state, RedisWatchOutcome $outcome): bool
    {
        \assert(null !== $this->edge);
        try {
            $this->edge->purgeEverything();
        } catch (\RuntimeException $e) {
            $state->edgePurgePending = true;
            $outcome->say(\sprintf('Purging %s failed: %s', $this->edge->name(), $e->getMessage()));

            return false;
        }
        $state->edgePurgePending = false;
        $outcome->say(\sprintf('Purged everything in %s.', $this->edge->name()));

        return true;
    }

    private function notify(RedisWatchOutcome $outcome, string $subject, string $body): string
    {
        $result = $this->notifier->send($subject, $body);
        $outcome->say(match ($result) {
            Notifier::SENT => 'Emailed: '.$subject,
            Notifier::NO_RECIPIENTS => 'No email (MAILER_EMAIL is empty): '.$subject,
            default => 'The email failed; the next run tries again: '.$subject,
        });

        return $result;
    }

    private static function time(?\DateTimeImmutable $time): string
    {
        return null === $time ? 'an unknown time' : $time->setTimezone(new \DateTimeZone('UTC'))->format('Y-m-d H:i:s').' UTC';
    }
}
