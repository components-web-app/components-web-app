<?php

declare(strict_types=1);

namespace App\Tests\Unit\Flysystem;

use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;

// Flysystem's public_url skips the adapter's prefix, so media and imagine URLs must add it exactly once (#166).
class MediaPublicUrlTest extends KernelTestCase
{
    private array $env;

    protected function setUp(): void
    {
        $this->env = $_ENV;
    }

    protected function tearDown(): void
    {
        $_ENV = $this->env;
        parent::tearDown();
    }

    public function test_the_media_url_includes_the_prefix_once(): void
    {
        $_ENV['GCLOUD_PUBLIC_URL'] = 'https://cdn.example.com/';
        $_ENV['GCLOUD_PATH_PREFIX'] = '/review/my-branch';
        self::bootKernel();

        self::assertSame('https://cdn.example.com/review/my-branch/', static::getContainer()->getParameter('app.media_public_url'));
    }

    public function test_no_prefix_leaves_the_media_url_unchanged(): void
    {
        $_ENV['GCLOUD_PUBLIC_URL'] = 'https://cdn.example.com/';
        $_ENV['GCLOUD_PATH_PREFIX'] = '';
        self::bootKernel();

        self::assertSame('https://cdn.example.com/', static::getContainer()->getParameter('app.media_public_url'));
    }
}
