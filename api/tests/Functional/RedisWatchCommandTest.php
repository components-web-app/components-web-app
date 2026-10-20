<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use App\Entity\RedisWatchState;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Console\Application;
use Symfony\Component\Console\Tester\CommandTester;

/**
 * The Redis watch command (#85) keeps its state in the database across runs, and waits for a new release's migration.
 */
final class RedisWatchCommandTest extends FunctionalTestCase
{
    public function testAnOutageIsStoredAndEmailedOnce(): void
    {
        $first = $this->tester();
        self::assertSame(0, $first->execute($this->arguments()), $first->getDisplay());
        self::assertStringContainsString('Redis is unreachable', $first->getDisplay());
        self::assertStringContainsString('the cache store (Redis) is unreachable', $first->getDisplay());

        $state = $this->state();
        self::assertNotNull($state?->downSince);
        self::assertTrue($state->downNotified);

        $second = $this->tester();
        self::assertSame(0, $second->execute($this->arguments()), $second->getDisplay());
        self::assertStringContainsString('already emailed', $second->getDisplay());
        self::assertEquals($state->downSince, $this->state()?->downSince);
    }

    public function testWaitsForTheMigration(): void
    {
        $manager = self::getContainer()->get('doctrine')->getManager();
        \assert($manager instanceof EntityManagerInterface);
        $manager->getConnection()->executeStatement('DROP TABLE redis_watch_state');

        $tester = $this->tester();
        self::assertSame(0, $tester->execute($this->arguments()), $tester->getDisplay());
        self::assertStringContainsString('not migrated yet', $tester->getDisplay());
    }

    public function testNeedsItsTargets(): void
    {
        self::assertSame(2, $this->tester()->execute([]));
    }

    /**
     * @return array<string, string>
     */
    private function arguments(): array
    {
        // Nothing listens on port 1: Redis and the API are both unreachable.
        return ['--redis' => '127.0.0.1:1', '--api-url' => 'http://127.0.0.1:1', '--attempts' => '1', '--timeout' => '0.5'];
    }

    private function tester(): CommandTester
    {
        $application = new Application(self::$kernel);

        return new CommandTester($application->find('app:redis-watch'));
    }

    private function state(): ?RedisWatchState
    {
        $manager = self::getContainer()->get('doctrine')->getManager();
        \assert($manager instanceof EntityManagerInterface);
        $manager->clear();

        return $manager->find(RedisWatchState::class, RedisWatchState::ID);
    }
}
