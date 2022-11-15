<?php

use Symfony\Component\DependencyInjection\Loader\Configurator\ContainerConfigurator;

return static function (ContainerConfigurator $configurator) {
    $services = $configurator->services();
    $services
        ->defaults()
        ->autowire()
        ->autoconfigure();

    $services
        ->load('App\\Features\\Bootstrap\\', '../features/bootstrap/*');

    /*
    Yaml from API Components Bundles
    app.imagine.cache.resolver.local:
        class: Silverback\ApiComponentsBundle\Imagine\FlysystemCacheResolver
        arguments:
            $filesystem: "@api_components.filesystem.in_memory"
            $rootUrl: ''
            $cachePrefix: 'media/cache'
            $visibility: 'private'
        tags:
            - { name: "liip_imagine.cache.resolver", resolver: custom_cache_resolver }

    monolog.formatter.stacktrace:
        class: Monolog\Formatter\LineFormatter
        calls:
            - [includeStacktraces]

    mercure.hub.default:
        class: Silverback\ApiComponentsBundle\Tests\Functional\TestBundle\Stub\HubStub
        arguments:
            $factory: '@mercure.hub.default.jwt.factory'

    # Test service to provide responses to the mock http client
    Silverback\ApiComponentsBundle\Tests\Functional\MockClientCallback: ~
    */
};
