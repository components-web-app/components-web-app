<?php

declare(strict_types=1);

namespace App\Flysystem;

use League\Flysystem\FilesystemAdapter;
use League\Flysystem\Local\LocalFilesystemAdapter;
use Symfony\Component\DependencyInjection\Exception\RuntimeException;

// The media adapter (the bundle's `gcloud` alias), chosen at runtime by MEDIA_STORAGE (#211): files under public/uploads, or Cloud Storage.
class MediaAdapterFactory
{
    public const string LOCAL = 'local';
    public const string GCLOUD = 'gcloud';

    /** @param \Closure(): GoogleCloudStorageFactory $gcloud built only for gcloud, so local needs no bucket settings */
    public function __construct(private readonly string $storage, private readonly string $localRoot, private readonly string $pathPrefix, private readonly \Closure $gcloud)
    {}

    public function __invoke(): FilesystemAdapter
    {
        return match (self::storage($this->storage)) {
            self::LOCAL => new LocalFilesystemAdapter(rtrim($this->localRoot, '/') . '/' . $this->pathPrefix, lazyRootCreation: true),
            self::GCLOUD => (($this->gcloud)())(),
        };
    }

    // MEDIA_STORAGE's value, or an error naming the two it accepts.
    public static function storage(string $value): string
    {
        $storage = strtolower(trim($value));
        if (self::LOCAL !== $storage && self::GCLOUD !== $storage) {
            throw new RuntimeException(sprintf('MEDIA_STORAGE must be "local" or "gcloud": "%s".', $value));
        }

        return $storage;
    }
}
