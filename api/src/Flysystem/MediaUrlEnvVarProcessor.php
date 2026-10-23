<?php

declare(strict_types=1);

namespace App\Flysystem;

use Symfony\Component\DependencyInjection\EnvVarProcessorInterface;

// %env(media_url:MEDIA_STORAGE)%: where media is served from, with a trailing slash and before the path prefix (#211).
final class MediaUrlEnvVarProcessor implements EnvVarProcessorInterface
{
    public function getEnv(string $prefix, string $name, \Closure $getEnv): string
    {
        if (MediaAdapterFactory::LOCAL === MediaAdapterFactory::storage((string) $getEnv($name))) {
            return sprintf('https://%s/uploads/', $getEnv('BROWSER_SERVER_NAME'));
        }

        // A CDN in front of the bucket, else the bucket's own public URL (#68).
        $publicUrl = (string) $getEnv('GCLOUD_PUBLIC_URL');

        return '' !== $publicUrl ? $publicUrl : sprintf('https://storage.googleapis.com/%s/', $getEnv('GCLOUD_BUCKET'));
    }

    public static function getProvidedTypes(): array
    {
        return ['media_url' => 'string'];
    }
}
