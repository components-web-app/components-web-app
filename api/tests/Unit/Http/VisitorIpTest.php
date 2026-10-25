<?php

declare(strict_types=1);

namespace App\Tests\Unit\Http;

use App\Http\VisitorIp;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use Symfony\Component\HttpFoundation\Request;

class VisitorIpTest extends TestCase
{
    /** @return iterable<string, array{?string, string}> */
    public static function cases(): iterable
    {
        yield 'Caddy\'s visitor' => ['203.0.113.9', '203.0.113.9'];
        yield 'IPv6' => ['2001:db8::1', '2001:db8::1'];
        yield 'an unknown proxy: its own address' => ['198.51.100.7 203.0.113.9, 10.0.0.1', '198.51.100.7'];
        yield 'not an address' => ['nonsense', '192.0.2.1'];
        yield 'empty' => ['', '192.0.2.1'];
        yield 'no Caddy (console, functional tests)' => [null, '192.0.2.1'];
    }

    #[DataProvider('cases')]
    public function test_the_visitor_comes_from_caddy_else_the_client_ip(?string $caddy, string $expected): void
    {
        $server = ['REMOTE_ADDR' => '192.0.2.1'];
        if (null !== $caddy) {
            $server['CWA_VISITOR_IP'] = $caddy;
        }

        self::assertSame($expected, (new VisitorIp())->of(Request::create('/', server: $server)));
    }

    public function test_a_request_header_is_never_the_visitor(): void
    {
        $request = Request::create('/', server: ['REMOTE_ADDR' => '192.0.2.1', 'HTTP_CWA_VISITOR_IP' => '6.6.6.6']);

        self::assertSame('192.0.2.1', (new VisitorIp())->of($request));
    }
}
