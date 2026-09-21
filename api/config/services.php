<?php

declare(strict_types=1);

namespace App\Resources\config;

use App\DataFixtures\AppScaffold;
use App\DataFixtures\UsersFixture;
use App\Flysystem\GoogleCloudStorageFactory;
use App\Mercure\SkipAwareMercureHub;
use League\Flysystem\GoogleCloudStorage\GoogleCloudStorageAdapter;
use League\Flysystem\Local\LocalFilesystemAdapter;
use Silverback\ApiComponentsBundle\Flysystem\FilesystemProvider;
use Silverback\ApiComponentsBundle\Imagine\FlysystemCacheResolver;
use Symfony\Component\DependencyInjection\Loader\Configurator\ContainerConfigurator;
use Symfony\Component\DependencyInjection\Loader\Configurator\ReferenceConfigurator;
use function Symfony\Component\DependencyInjection\Loader\Configurator\tagged_iterator;
use Symfony\Component\DependencyInjection\Reference;


return static function (ContainerConfigurator $configurator) {
    $configurator
        ->parameters()
        ->set('locale', 'en')
        ->set('env(GCLOUD_JSON)', '{}')
        // Public base URL that uploaded media and cached image URLs are built on.
        // Point it at a CDN in front of the bucket where there is one. Left empty,
        // it falls back to the bucket's own public URL, so a project that has not
        // configured a CDN still gets working URLs - never somebody else's domain.
        // Must end in a slash; it is concatenated with the object path.
        ->set('env(GCLOUD_PUBLIC_URL)', '')
        ->set('app.gcloud_bucket_public_url', 'https://storage.googleapis.com/%env(GCLOUD_BUCKET)%/')
        ->set('app.media_public_url', '%env(default:app.gcloud_bucket_public_url:GCLOUD_PUBLIC_URL)%')
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
        ->set(AppScaffold::class)
        ->args(['$parts' => tagged_iterator('cwa.scaffold_part', defaultPriorityMethod: 'getPriority')])
    ;

    $services
        ->set(LocalFilesystemAdapter::class)
        ->args([
            '%kernel.project_dir%/var/storage/default'
        ])
        ->tag(FilesystemProvider::FILESYSTEM_ADAPTER_TAG, [ 'alias' => 'local' ]);

    // api_components.filesystem.gcloud is a service with a factory Silverback\ApiComponentsBundle\Flysystem\FilesystemProvider
    // we need to override this filesystem provider or have acb config options to pass configs into this provider
//    $services
//        ->alias('api_platform.http_cache.purger', 'api_platform.http_cache.purger.varnish.xkey');

    if ($configurator->env() !== 'prod') {
        $services
            ->set(FlysystemCacheResolver::class)
            ->args([
                '$filesystem' => new Reference("api_components.filesystem.gcloud"),
                '$rootUrl' => '/uploads/',
                '$cachePrefix' => 'cache',
                '$visibility' => 'public'
            ])
            ->tag('liip_imagine.cache.resolver', [ 'resolver' => 'in_memory_cache_resolver' ]);

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
            // Only public_url is honoured here. This config array becomes League
            // Flysystem's Filesystem config, which reads `public_url` and nothing
            // else relevant - a `prefix` key in it is silently ignored. A bucket
            // path prefix has to be passed to the GoogleCloudStorageAdapter
            // constructor instead (see App\Flysystem\GoogleCloudStorageFactory).
            ->tag(FilesystemProvider::FILESYSTEM_ADAPTER_TAG, [ 'alias' => 'gcloud', 'config' => [ 'public_url' => '%app.media_public_url%' ] ]);
        $services
            ->set(FlysystemCacheResolver::class)
            ->args([
                '$filesystem' => new Reference("api_components.filesystem.gcloud"),
                '$rootUrl' => '%app.media_public_url%',
                '$cachePrefix' => 'cache',
                '$visibility' => 'public'
            ])
            ->tag('liip_imagine.cache.resolver', [ 'resolver' => 'in_memory_cache_resolver' ]);
    }


    $services
        ->set(SkipAwareMercureHub::class)
        ->decorate('mercure.hub.default')
        ->args([new Reference(SkipAwareMercureHub::class . '.inner')]);

    $envServicesFile = sprintf('services_%s.php', $configurator->env());
    $configurator->import($envServicesFile, null, 'not_found');
};
