<?php

declare(strict_types=1);

namespace App\Resources\config;

use App\Flysystem\GoogleCloudStorageFactory;
use App\Mercure\SkipAwareMercureHub;
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
        // Public base URL for media (a CDN in front of the bucket), with a trailing slash. Empty falls back to the
        // bucket's own public URL (#68).
        ->set('env(GCLOUD_PUBLIC_URL)', '')
        ->set('app.gcloud_bucket_public_url', 'https://storage.googleapis.com/%env(GCLOUD_BUCKET)%/')
        ->set('app.media_public_url', '%env(default:app.gcloud_bucket_public_url:GCLOUD_PUBLIC_URL)%')
        // Origin for links in user emails; the bundle refuses those emails without one. Defaults to the public host.
        ->set('env(EMAIL_LINK_DEFAULT_ORIGIN)', '')
        ->set('app.browser_origin', 'https://%env(BROWSER_SERVER_NAME)%')
        ->set('app.email_link_default_origin', '%env(default:app.browser_origin:EMAIL_LINK_DEFAULT_ORIGIN)%')
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
        ->set(LocalFilesystemAdapter::class)
        ->args([
            '%kernel.project_dir%/var/storage/default'
        ])
        ->tag(FilesystemProvider::FILESYSTEM_ADAPTER_TAG, [ 'alias' => 'local' ]);

    // The gcloud filesystem is built by the bundle's FilesystemProvider; its adapter is configured below.

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
            // Flysystem reads only public_url from this config; a bucket prefix goes to the adapter's constructor
            // (App\Flysystem\GoogleCloudStorageFactory).
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
