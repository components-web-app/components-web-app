<?php

declare(strict_types=1);

namespace App\Tests\Unit;

use PHPUnit\Framework\TestCase;

// The postStart br warm reads manifests only if php can decode br (#175); keep the brotli extension in the image.
class BrotliExtensionTest extends TestCase
{
    public function test_php_can_decode_brotli(): void
    {
        self::assertTrue(\function_exists('brotli_uncompress'), 'The php image needs the brotli extension.');
        self::assertSame('{"a":1}', brotli_uncompress(brotli_compress('{"a":1}')));
    }
}
