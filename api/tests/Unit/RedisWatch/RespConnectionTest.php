<?php

declare(strict_types=1);

namespace App\Tests\Unit\RedisWatch;

use App\RedisWatch\RedisUnavailable;
use App\RedisWatch\RespConnection;
use PHPUnit\Framework\TestCase;

/**
 * The watch job's Redis client (#85), against canned replies on a socket pair.
 */
final class RespConnectionTest extends TestCase
{
    /** @var resource */
    private $server;

    private RespConnection $connection;

    protected function setUp(): void
    {
        $pair = stream_socket_pair(STREAM_PF_UNIX, STREAM_SOCK_STREAM, STREAM_IPPROTO_IP);
        self::assertIsArray($pair);
        [$client, $this->server] = $pair;
        stream_set_timeout($client, 1);
        $this->connection = new RespConnection($client);
    }

    protected function tearDown(): void
    {
        $this->connection->close();
        if (\is_resource($this->server)) {
            fclose($this->server);
        }
    }

    public function testSendsACommandAsARespArray(): void
    {
        fwrite($this->server, "+OK\r\n");
        self::assertSame('OK', $this->connection->command('FLUSHDB', 'ASYNC'));
        self::assertSame("*2\r\n\$7\r\nFLUSHDB\r\n\$5\r\nASYNC\r\n", fread($this->server, 1024));
    }

    public function testReadsEveryReplyType(): void
    {
        $info = "# Server\r\nredis_version:8.10.2\r\nrun_id:abc123\r\n";
        fwrite($this->server, '$'.\strlen($info)."\r\n".$info."\r\n");
        self::assertSame($info, $this->connection->command('INFO', 'server'));

        fwrite($this->server, ":42\r\n");
        self::assertSame(42, $this->connection->command('DBSIZE'));

        fwrite($this->server, "\$-1\r\n");
        self::assertNull($this->connection->command('GET', 'missing'));

        fwrite($this->server, "*2\r\n\$1\r\na\r\n:1\r\n");
        self::assertSame(['a', 1], $this->connection->command('X'));
    }

    public function testAnErrorReplyThrowsWithoutTheRestOfTheMessage(): void
    {
        fwrite($this->server, "-WRONGPASS invalid username-password pair or user is disabled.\r\n");
        try {
            $this->connection->command('AUTH', 'secret');
            self::fail('No exception');
        } catch (RedisUnavailable $e) {
            self::assertSame('Redis answered WRONGPASS', $e->getMessage());
            self::assertStringNotContainsString('secret', $e->getMessage());
        }
    }

    public function testAClosedConnectionThrows(): void
    {
        fclose($this->server);
        $this->expectException(RedisUnavailable::class);
        $this->connection->command('PING');
    }

    public function testASilentServerTimesOut(): void
    {
        $this->expectExceptionObject(new RedisUnavailable('Redis did not answer in time'));
        $this->connection->command('PING');
    }

    public function testAnUnreachableAddressThrows(): void
    {
        $this->expectException(RedisUnavailable::class);
        RespConnection::open('127.0.0.1:1', '', 0.5);
    }
}
