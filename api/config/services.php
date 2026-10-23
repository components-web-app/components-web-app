<?php

declare(strict_types=1);

namespace App\Resources\config;

use App\Flysystem\GoogleCloudStorageFactory;
use App\Flysystem\MediaAdapterFactory;
use App\Mercure\SkipAwareMercureHub;
use League\Flysystem\FilesystemAdapter;
use League\Flysystem\Local\LocalFilesystemAdapter;
use Silverback\ApiComponentsBundle\Flysystem\FilesystemProvider;
use Silverback\ApiComponentsBundle\Imagine\FlysystemCacheResolver;
use Symfony\Component\DependencyInjection\Loader\Configurator\ContainerConfigurator;
use Symfony\Component\DependencyInjection\Loader\Configurator\ReferenceConfigurator;
use Symfony\Component\DependencyInjection\Reference;

use function Symfony\Component\DependencyInjection\Loader\Configurator\service_closure;


return static function (ContainerConfigurator $configurator) {
    $configurator
        ->parameters()
        ->set('locale', 'en')
        ->set('env(GCLOUD_JSON)', '{}')
        // The database backup's own key, never the media key (#180); only the backup Job has it.
        ->set('env(DATABASE_BACKUP_GCLOUD_JSON)', '{}')
        // Public base URL for media (a CDN in front of the bucket), with a trailing slash. Empty falls back to the
        // bucket's own public URL (#68).
        ->set('env(GCLOUD_PUBLIC_URL)', '')
        // A Cloud Storage emulator (e.g. http://gcs:4443) instead of Google, for the browser tests (#157). Empty uses Google.
        ->set('env(GCLOUD_API_ENDPOINT)', '')
        // Path inside the bucket for this app's objects, e.g. review/<slug>/ (#166). Empty stores at the bucket root.
        ->set('env(GCLOUD_PATH_PREFIX)', '')
        // Where media is stored (#211): local (public/uploads, served at /uploads/) or gcloud. Deploys default to gcloud.
        ->set('env(MEDIA_STORAGE)', 'prod' === $configurator->env() ? 'gcloud' : 'local')
        ->set('app.storage_path_prefix', '%env(storage_prefix:GCLOUD_PATH_PREFIX)%')
        // public_url bypasses the adapter's prefix, so media URLs add it here, once (#166).
        ->set('app.media_public_url', '%env(media_url:MEDIA_STORAGE)%%app.storage_path_prefix%')
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

    // The gcloud filesystem is built by the bundle's FilesystemProvider, from the adapter MEDIA_STORAGE picks at runtime (#211).
    $services
        ->set(GoogleCloudStorageFactory::class)
        ->args([
            '%env(json:GCLOUD_JSON)%',
            '%env(GCLOUD_BUCKET)%',
            '%env(GCLOUD_API_ENDPOINT)%',
            '%app.storage_path_prefix%',
        ])
    ;
    $services
        ->set(MediaAdapterFactory::class)
        ->args([
            '%env(MEDIA_STORAGE)%',
            '%kernel.project_dir%/public/uploads',
            '%app.storage_path_prefix%',
            service_closure(GoogleCloudStorageFactory::class),
        ])
    ;
    $services
        ->set('app.media_adapter', FilesystemAdapter::class)
        ->factory(new ReferenceConfigurator(MediaAdapterFactory::class))
        // Flysystem reads only public_url from this config; the path prefix goes to the adapter (#166).
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

    $services
        ->set(SkipAwareMercureHub::class)
        ->decorate('mercure.hub.default')
        ->args([new Reference(SkipAwareMercureHub::class . '.inner')]);

    $envServicesFile = sprintf('services_%s.php', $configurator->env());
    $configurator->import($envServicesFile, null, 'not_found');
};
