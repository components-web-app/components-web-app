<?php

declare(strict_types=1);

namespace App\Tests\Unit;

use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;

// The services resetter must clear API Platform's genid map between worker requests (#161, api-platform/core#8680).
class SkolemIriConverterResetTest extends KernelTestCase
{
    public function test_the_services_resetter_clears_the_genid_map(): void
    {
        self::bootKernel();
        $container = static::getContainer();
        $skolem = $container->get('api_platform.symfony.iri_converter.skolem');
        $map = new \ReflectionProperty($skolem, 'objectHashMap');

        $skolem->getIriFromResource(new \stdClass());
        self::assertCount(1, $map->getValue($skolem));

        $container->get('services_resetter')->reset();

        self::assertCount(0, $map->getValue($skolem));
    }
}
