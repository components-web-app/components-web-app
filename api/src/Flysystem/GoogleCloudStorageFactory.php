<?php

namespace App\Flysystem;

use Google\Cloud\Storage\StorageClient;
use League\Flysystem\GoogleCloudStorage\GoogleCloudStorageAdapter;
use League\Flysystem\GoogleCloudStorage\UniformBucketLevelAccessVisibility;

class GoogleCloudStorageFactory
{
    public function __construct(private readonly array $keyFile, private readonly string $bucket)
    {}

    public function __invoke(): GoogleCloudStorageAdapter
    {
        $clientOptions = [
            'projectId' => $this->keyFile['project_id'] ?? null,
            'keyFile'   => $this->keyFile,
        ];

        $storageClient = new StorageClient($clientOptions);
        $bucket = $storageClient->bucket($this->bucket);

        return new GoogleCloudStorageAdapter(bucket: $bucket, visibilityHandler: new UniformBucketLevelAccessVisibility());
    }
}
