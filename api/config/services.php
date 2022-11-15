<?php

declare(strict_types=1);

namespace App\Resources\config;

use App\Flysystem\GoogleCloudStorageFactory;
use League\Flysystem\GoogleCloudStorage\GoogleCloudStorageAdapter;
use League\Flysystem\Local\LocalFilesystemAdapter;
use Silverback\ApiComponentsBundle\Flysystem\FilesystemProvider;
use Symfony\Component\DependencyInjection\Loader\Configurator\ContainerConfigurator;
use Symfony\Component\DependencyInjection\Loader\Configurator\ReferenceConfigurator;


return static function (ContainerConfigurator $configurator) {
    $configurator->parameters()->set('locale', 'en')->set('env(GCLOUD_JSON)', '{}');

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

    $services
        ->alias('api_platform.http_cache.purger', 'api_platform.http_cache.purger.varnish.xkey');

//    $services
//        ->set(FlysystemCacheResolver::class)
//        ->args([
//            '$filesystem' => "@api_components.filesystem.local",
//            '$rootUrl' => 'http://images.example.com',
//            '$cachePrefix' => 'media/cache',
//            '$visibility' => 'public'
//        ])
//        ->tag(FilesystemProvider::FILESYSTEM_ADAPTER_TAG, [ 'alias' => 'local' ]);


    $envServicesFile = sprintf('services_%s.php', $configurator->env());
    $configurator->import($envServicesFile, null, 'not_found');
};
