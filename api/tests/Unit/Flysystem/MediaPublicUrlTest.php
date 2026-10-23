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
        $_ENV['MEDIA_STORAGE'] = 'gcloud';
        $_ENV['GCLOUD_PUBLIC_URL'] = 'https://cdn.example.com/';
        $_ENV['GCLOUD_PATH_PREFIX'] = '/review/my-branch';
        self::bootKernel();

        self::assertSame('https://cdn.example.com/review/my-branch/', static::getContainer()->getParameter('app.media_public_url'));
    }

    public function test_no_prefix_leaves_the_media_url_unchanged(): void
    {
        $_ENV['MEDIA_STORAGE'] = 'gcloud';
        $_ENV['GCLOUD_PUBLIC_URL'] = 'https://cdn.example.com/';
        $_ENV['GCLOUD_PATH_PREFIX'] = '';
        self::bootKernel();

        self::assertSame('https://cdn.example.com/', static::getContainer()->getParameter('app.media_public_url'));
    }

    public function test_no_public_url_falls_back_to_the_bucket(): void
    {
        $_ENV['MEDIA_STORAGE'] = 'gcloud';
        $_ENV['GCLOUD_BUCKET'] = 'my-bucket';
        $_ENV['GCLOUD_PUBLIC_URL'] = '';
        $_ENV['GCLOUD_PATH_PREFIX'] = '';
        self::bootKernel();

        self::assertSame('https://storage.googleapis.com/my-bucket/', static::getContainer()->getParameter('app.media_public_url'));
    }

    // Local media is served by Caddy from public/uploads on the site's own host (#211).
    public function test_local_media_is_served_from_uploads_with_the_prefix(): void
    {
        $_ENV['MEDIA_STORAGE'] = 'local';
        $_ENV['BROWSER_SERVER_NAME'] = 'www.example.com';
        $_ENV['GCLOUD_PUBLIC_URL'] = 'https://cdn.example.com/';
        $_ENV['GCLOUD_PATH_PREFIX'] = 'site-a';
        self::bootKernel();

        self::assertSame('https://www.example.com/uploads/site-a/', static::getContainer()->getParameter('app.media_public_url'));
    }

    public function test_an_unknown_storage_is_refused(): void
    {
        $_ENV['MEDIA_STORAGE'] = 's3';
        self::bootKernel();

        $this->expectExceptionMessage('MEDIA_STORAGE must be "local" or "gcloud": "s3".');
        static::getContainer()->getParameter('app.media_public_url');
    }
}
