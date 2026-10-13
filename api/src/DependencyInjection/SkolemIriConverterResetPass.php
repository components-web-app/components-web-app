<?php

declare(strict_types=1);

namespace App\DependencyInjection;

use Symfony\Component\DependencyInjection\Compiler\CompilerPassInterface;
use Symfony\Component\DependencyInjection\ContainerBuilder;

// Hotfix: resets API Platform's genid map between worker requests (#161, api-platform/core#8680); delete once a release has core#8681.
final class SkolemIriConverterResetPass implements CompilerPassInterface
{
    private const SERVICE = 'api_platform.symfony.iri_converter.skolem';

    public function process(ContainerBuilder $container): void
    {
        if ($container->hasDefinition(self::SERVICE) && !$container->getDefinition(self::SERVICE)->hasTag('kernel.reset')) {
            $container->getDefinition(self::SERVICE)->addTag('kernel.reset', ['method' => 'reset']);
        }
    }
}
