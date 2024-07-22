<?php

declare(strict_types=1);

namespace App\Resources\config;

use App\DataFixtures\UsersFixture;
use App\Flysystem\GoogleCloudStorageFactory;
use League\Flysystem\GoogleCloudStorage\GoogleCloudStorageAdapter;
use League\Flysystem\Local\LocalFilesystemAdapter;
use Silverback\ApiComponentsBundle\Flysystem\FilesystemProvider;
use Silverback\ApiComponentsBundle\Imagine\FlysystemCacheResolver;
use Symfony\Component\DependencyInjection\Loader\Configurator\ContainerConfigurator;
use Symfony\Component\DependencyInjection\Loader\Configurator\ReferenceConfigurator;
use Symfony\Component\DependencyInjection\Reference;


return static function (ContainerConfigurator $configurator) {
    $configurator
        ->parameters()
        ->set('locale', 'en')
        ->set('env(GCLOUD_JSON)', '{}')
        ->set('env(ADMIN_USERNAME)', null)
        ->set('env(ADMIN_PASSWORD)', null)
        ->set('env(ADMIN_EMAIL)', null)
    ;

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
        ->set(UsersFixture::class)
        ->args([
            '$adminUsername' => '%env(ADMIN_USERNAME)%',
            '$adminPassword' => '%env(ADMIN_PASSWORD)%',
            '$adminEmail' => '%env(ADMIN_EMAIL)%'
        ])
    ;

    $services
        ->set(LocalFilesystemAdapter::class)
        ->args([
            '%kernel.project_dir%/var/storage/default'
        ])
        ->tag(FilesystemProvider::FILESYSTEM_ADAPTER_TAG, [ 'alias' => 'local' ]);

    // api_components.filesystem.gcloud is a service with a factory Silverback\ApiComponentsBundle\Flysystem\FilesystemProvider
    // we need to override this filesystem provider or have acb config options to pass configs into this provider
    $services
        ->alias('api_platform.http_cache.purger', 'api_platform.http_cache.purger.varnish.xkey');

    $services
        ->set(FlysystemCacheResolver::class)
        ->args([
            '$filesystem' => new Reference("api_components.filesystem.gcloud"),
            '$rootUrl' => '/uploads/',
            '$cachePrefix' => 'cache',
            '$visibility' => 'public'
        ])
        ->tag('liip_imagine.cache.resolver', [ 'resolver' => 'in_memory_cache_resolver' ]);

    if ($configurator->env() !== 'prod') {
        $services
            ->set(LocalFilesystemAdapter::class)
            ->args(
                [
                    '%kernel.project_dir%/public/uploads',
                ]
            )
            ->tag(FilesystemProvider::FILESYSTEM_ADAPTER_TAG, ['alias' => 'gcloud']);
    } else {
        $services
            ->set(GoogleCloudStorageFactory::class)
            ->args([
                '%env(json:GCLOUD_JSON)%',
                '%env(GCLOUD_BUCKET)%'
            ])
        ;
        $services
            ->set(GoogleCloudStorageAdapter::class)
            ->factory(new ReferenceConfigurator(GoogleCloudStorageFactory::class))
            ->tag(FilesystemProvider::FILESYSTEM_ADAPTER_TAG, [ 'alias' => 'gcloud', 'config' => [ 'public_url' => 'https://cdn.silverbackwebapps.com/cwa' ] ]);
    }


    $envServicesFile = sprintf('services_%s.php', $configurator->env());
    $configurator->import($envServicesFile, null, 'not_found');
};
