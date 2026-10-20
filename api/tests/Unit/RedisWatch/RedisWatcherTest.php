<?php

declare(strict_types=1);

namespace App\Tests\Unit\RedisWatch;

use App\Entity\RedisWatchState;
use App\RedisWatch\CacheStore;
use App\RedisWatch\EdgeCache;
use App\RedisWatch\Notifier;
use App\RedisWatch\PhpView;
use App\RedisWatch\PhpViewResult;
use App\RedisWatch\RedisUnavailable;
use App\RedisWatch\RedisWatcher;
use PHPUnit\Framework\TestCase;

/**
 * The Redis watch job's runs (#85): one email per outage, one flush when Redis is back, CDN purge after the flush.
 */
final class RedisWatcherTest extends TestCase
{
    private FakeStore $store;
    private FakePhpView $php;
    private FakeNotifier $notifier;
    private FakeEdge $edge;
    private RedisWatchState $state;
    private int $minute = 0;

    protected function setUp(): void
    {
        $this->store = new FakeStore();
        $this->php = new FakePhpView();
        $this->notifier = new FakeNotifier();
        $this->edge = new FakeEdge();
        $this->state = new RedisWatchState();
    }

    public function testAHealthyRedisDoesNothing(): void
    {
        $this->check();
        $outcome = $this->check();

        self::assertFalse($outcome->failed);
        self::assertSame(['Redis is reachable.'], $outcome->lines);
        self::assertSame(0, $this->store->flushes);
        self::assertSame([], $this->notifier->subjects);
        self::assertSame('run-1', $this->state->redisRunId);
    }

    public function testAnOutageEmailsOnceThenFlushesOnceWhenRedisIsBack(): void
    {
        $this->check();
        $this->redisDown();

        $first = $this->check();
        $this->check();
        $this->check();

        self::assertFalse($first->failed);
        self::assertSame(['the cache store (Redis) is unreachable'], $this->notifier->subjects);
        self::assertSame(0, $this->store->flushes);
        self::assertNotNull($this->state->downSince);

        $this->redisUp();
        $back = $this->check();

        self::assertFalse($back->failed);
        self::assertSame(1, $this->store->flushes);
        self::assertSame(1, $this->edge->purges);
        self::assertSame('the cache store (Redis) is back; the cache was flushed', $this->notifier->subjects[1]);
        self::assertStringContainsString('purged everything in the edge', $this->notifier->bodies[1]);
        self::assertNull($this->state->downSince);

        $this->check();
        self::assertSame(1, $this->store->flushes, 'Flushed once only');
        self::assertCount(2, $this->notifier->subjects);
    }

    public function testPhpFailingAloneIsAnOutage(): void
    {
        $this->check();
        $this->php->result = PhpViewResult::redisError('detail=REDIS-INSERTION-ERROR');
        $this->check();
        self::assertNotNull($this->state->downSince);
        self::assertStringContainsString('php could not store in Redis', (string) $this->state->downReason);

        $this->php->result = PhpViewResult::ok('hit');
        $this->check();
        self::assertSame(1, $this->store->flushes);
    }

    public function testABlipThatClearsWithinTheAttemptsIsNotAnOutage(): void
    {
        $this->php->results = [PhpViewResult::redisError('detail=REDIS-INSERTION-ERROR'), PhpViewResult::ok('hit')];
        $outcome = $this->check();

        self::assertNull($this->state->downSince);
        self::assertSame([], $this->notifier->subjects);
        self::assertFalse($outcome->failed);
    }

    public function testOnlyThisJobFailingIsItsOwnFaultNotAnOutage(): void
    {
        $this->store->down = true;
        $this->php->result = PhpViewResult::ok('Souin; hit; detail=REDIS');
        $outcome = $this->check();

        self::assertTrue($outcome->failed);
        self::assertStringContainsString('php reaches Redis but this job can\'t', $outcome->lines[0]);
        self::assertNull($this->state->downSince);
        self::assertSame([], $this->notifier->subjects);
    }

    public function testUnreachableWithAnApiThatDoesNotAnswerIsAnOutage(): void
    {
        $this->store->down = true;
        $this->php->result = PhpViewResult::unknown('the API did not answer');
        $this->check();

        self::assertNotNull($this->state->downSince);
        self::assertCount(1, $this->notifier->subjects);
    }

    public function testAFailedFlushKeepsTheOutageOpenForTheNextRun(): void
    {
        $this->check();
        $this->redisDown();
        $this->check();
        $this->redisUp();
        $this->store->flushFails = true;

        $outcome = $this->check();
        self::assertTrue($outcome->failed);
        self::assertNotNull($this->state->downSince);
        self::assertCount(1, $this->notifier->subjects);

        $this->store->flushFails = false;
        $this->check();
        self::assertSame(1, $this->store->flushes);
        self::assertNull($this->state->downSince);
    }

    public function testAFailedCdnPurgeIsRetriedWithoutFlushingRedisAgain(): void
    {
        $this->check();
        $this->redisDown();
        $this->check();
        $this->redisUp();
        $this->edge->fails = true;

        $back = $this->check();
        self::assertFalse($back->failed, 'Redis was flushed; the CDN retry is next run\'s job');
        self::assertTrue($this->state->edgePurgePending);
        self::assertStringContainsString('Purging the edge failed', $this->notifier->bodies[1]);

        $this->edge->fails = false;
        $this->check();
        self::assertFalse($this->state->edgePurgePending);
        self::assertSame(1, $this->store->flushes);
        self::assertSame(1, $this->edge->purges);
    }

    public function testARestartBetweenRunsEmailsButDoesNotFlush(): void
    {
        $this->check();
        $this->store->runId = 'run-2';
        $outcome = $this->check();

        self::assertSame(0, $this->store->flushes);
        self::assertSame(['Redis restarted'], $this->notifier->subjects);
        self::assertSame('run-2', $this->state->redisRunId);
        self::assertFalse($outcome->failed);
    }

    public function testARestartWithANewReleaseRevisionWasADeployAndSendsNoEmail(): void
    {
        $this->check('7');
        $this->store->runId = 'run-2';
        $outcome = $this->check('8');

        self::assertSame([], $this->notifier->subjects);
        self::assertSame(0, $this->store->flushes);
        self::assertSame('8', $this->state->releaseRevision);
        self::assertStringContainsString('deploy revision 8', implode("\n", $outcome->lines));
    }

    public function testARestartWithinOneReleaseRevisionStillEmails(): void
    {
        $this->check('7');
        $this->store->runId = 'run-2';
        $this->check('7');

        self::assertSame(['Redis restarted'], $this->notifier->subjects);
    }

    public function testWithoutACdnItOnlyFlushesRedis(): void
    {
        $watcher = new RedisWatcher($this->store, $this->php, $this->notifier, null, 1, 0, static function (): void {});
        $watcher->run($this->state, $this->now());
        $this->redisDown();
        $watcher->run($this->state, $this->now());
        $this->redisUp();
        $watcher->run($this->state, $this->now());

        self::assertSame(1, $this->store->flushes);
        self::assertStringNotContainsString('edge', $this->notifier->bodies[1]);
    }

    public function testAFailedOutageEmailIsSentNextRun(): void
    {
        $this->redisDown();
        $this->notifier->result = Notifier::FAILED;
        $this->check();
        self::assertFalse($this->state->downNotified);

        $this->notifier->result = Notifier::SENT;
        $this->check();
        self::assertTrue($this->state->downNotified);
        $this->check();
        self::assertCount(2, $this->notifier->subjects, 'One failed attempt, one sent, none after');
    }

    public function testAFailedRecoveryEmailIsSentNextRunWithoutFlushingAgain(): void
    {
        $this->check();
        $this->redisDown();
        $this->check();
        $this->redisUp();
        $this->notifier->result = Notifier::FAILED;

        $back = $this->check();
        self::assertFalse($back->failed);
        self::assertNull($this->state->downSince);
        self::assertNotNull($this->state->recoveryEmail);

        $this->notifier->result = Notifier::SENT;
        $this->check();
        self::assertNull($this->state->recoveryEmail);
        self::assertSame(1, $this->store->flushes);
        self::assertSame(1, $this->edge->purges);
        self::assertSame($this->notifier->bodies[1], $this->notifier->bodies[2], 'The retry sends the same email');
        self::assertSame('the cache store (Redis) is back; the cache was flushed', $this->notifier->subjects[2]);

        $this->check();
        self::assertCount(3, $this->notifier->subjects, 'Outage, failed recovery, sent recovery; none after');
    }

    private function redisDown(): void
    {
        $this->store->down = true;
        $this->php->result = PhpViewResult::redisError('Souin; fwd=uri-miss; detail=REDIS-INSERTION-ERROR');
    }

    private function redisUp(): void
    {
        $this->store->down = false;
        $this->php->result = PhpViewResult::ok('Souin; fwd=uri-miss; stored');
    }

    private function check(?string $revision = null): \App\RedisWatch\RedisWatchOutcome
    {
        return new RedisWatcher($this->store, $this->php, $this->notifier, $this->edge, 3, 0, static function (): void {})
            ->run($this->state, $this->now(), $revision);
    }

    private function now(): \DateTimeImmutable
    {
        return new \DateTimeImmutable('2026-10-20 10:00:00 UTC')->modify(\sprintf('+%d minutes', 2 * $this->minute++));
    }
}

final class FakeStore implements CacheStore
{
    public bool $down = false;
    public bool $flushFails = false;
    public string $runId = 'run-1';
    public int $flushes = 0;

    public function runId(): string
    {
        if ($this->down) {
            throw new RedisUnavailable('could not connect to redis:6379: Connection refused');
        }

        return $this->runId;
    }

    public function flush(): void
    {
        if ($this->down || $this->flushFails) {
            throw new RedisUnavailable('Redis did not answer in time');
        }
        ++$this->flushes;
    }
}

final class FakePhpView implements PhpView
{
    public PhpViewResult $result;

    /** @var list<PhpViewResult> */
    public array $results = [];

    public function __construct()
    {
        $this->result = PhpViewResult::ok('Souin; hit; detail=REDIS');
    }

    public function check(): PhpViewResult
    {
        return array_shift($this->results) ?? $this->result;
    }
}

final class FakeNotifier implements Notifier
{
    /** @var list<string> */
    public array $subjects = [];

    /** @var list<string> */
    public array $bodies = [];

    public string $result = Notifier::SENT;

    public function send(string $subject, string $body): string
    {
        $this->subjects[] = $subject;
        $this->bodies[] = $body;

        return $this->result;
    }
}

final class FakeEdge implements EdgeCache
{
    public bool $fails = false;
    public int $purges = 0;

    public function name(): string
    {
        return 'the edge';
    }

    public function purgeEverything(): void
    {
        if ($this->fails) {
            throw new \RuntimeException('Cloudflare answered 502');
        }
        ++$this->purges;
    }
}
