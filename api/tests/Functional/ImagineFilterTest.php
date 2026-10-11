<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use Liip\ImagineBundle\Imagine\Filter\FilterManager;
use Liip\ImagineBundle\Model\Binary;
use PHPUnit\Framework\Attributes\DataProvider;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;

/**
 * The configured filter sets on the configured driver: every variant is WebP (#149).
 */
class ImagineFilterTest extends KernelTestCase
{
    /**
     * @return iterable<string, array{string, int}>
     */
    public static function filterSets(): iterable
    {
        yield 'thumbnail' => ['thumbnail', 500];
        yield 'general' => ['general', 1200];
        yield 'large' => ['large', 2400];
    }

    #[DataProvider('filterSets')]
    public function test_a_png_upload_gets_a_webp_variant_that_keeps_transparency(string $filterSet, int $maxSize): void
    {
        $variant = $this->apply($filterSet, $this->image('png', 3000, 1000, transparent: true), 'image/png', 'png');

        self::assertSame('image/webp', $variant->getMimeType());
        self::assertSame('webp', $variant->getFormat());
        $image = imagecreatefromstring($variant->getContent());
        self::assertNotFalse($image);
        self::assertSame($maxSize, imagesx($image));
        // The top-left pixel was transparent in the upload.
        self::assertSame(127, (imagecolorat($image, 0, 0) >> 24) & 0x7F);
    }

    #[DataProvider('filterSets')]
    public function test_a_jpeg_upload_gets_a_webp_variant(string $filterSet, int $maxSize): void
    {
        $variant = $this->apply($filterSet, $this->image('jpeg', 3000, 2000), 'image/jpeg', 'jpeg');

        self::assertSame('image/webp', $variant->getMimeType());
        self::assertSame([$maxSize, intdiv($maxSize * 2, 3)], \array_slice(getimagesizefromstring($variant->getContent()) ?: [], 0, 2));
    }

    private function apply(string $filterSet, string $content, string $mimeType, string $format): Binary
    {
        $manager = self::getContainer()->get('liip_imagine.filter.manager');
        \assert($manager instanceof FilterManager);
        $variant = $manager->applyFilter(new Binary($content, $mimeType, $format), $filterSet);
        \assert($variant instanceof Binary);

        return $variant;
    }

    private function image(string $format, int $width, int $height, bool $transparent = false): string
    {
        $image = imagecreatetruecolor($width, $height);
        if ($transparent) {
            imagealphablending($image, false);
            imagesavealpha($image, true);
            imagefill($image, 0, 0, imagecolorallocatealpha($image, 0, 0, 0, 127));
        }
        imagefilledrectangle($image, (int) ($width / 4), (int) ($height / 4), (int) ($width * 3 / 4), (int) ($height * 3 / 4), imagecolorallocate($image, 30, 120, 150));
        ob_start();
        'png' === $format ? imagepng($image) : imagejpeg($image);

        return (string) ob_get_clean();
    }
}
