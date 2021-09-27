<?php

declare(strict_types=1);

namespace App\Resources\config;

use League\Flysystem\Local\LocalFilesystemAdapter;
use Silverback\ApiComponentsBundle\Flysystem\FilesystemProvider;
use Silverback\ApiComponentsBundle\Imagine\FlysystemCacheResolver;
use Symfony\Component\DependencyInjection\Loader\Configurator\ContainerConfigurator;

return static function (ContainerConfigurator $configurator) {
    $configurator->parameters()->set('locale', 'en');
    $services = $configurator->services();
    $services
        ->defaults()
        ->autowire()
        ->autoconfigure()
        ->private();

    $services
        ->load('App\\', '../src')
        ->exclude('../src/{Entity,Migrations,Tests,Kernel.php}');

    $services
        ->load('App\\Controller\\', '../src/Controller')
        ->tag('controller.service_subscriber');

    $services
        ->set(LocalFilesystemAdapter::class)
        ->args([
            '%kernel.project_dir%/var/storage/default'
        ])
        ->tag(FilesystemProvider::FILESYSTEM_ADAPTER_TAG, [ 'alias' => 'local' ]);

//    $services
//        ->set(FlysystemCacheResolver::class)
//        ->args([
//            '$filesystem' => "@api_components.filesystem.local",
//            '$rootUrl' => 'http://images.example.com',
//            '$cachePrefix' => 'media/cache',
//            '$visibility' => 'public'
//        ])
//        ->tag(FilesystemProvider::FILESYSTEM_ADAPTER_TAG, [ 'alias' => 'local' ]);
};
