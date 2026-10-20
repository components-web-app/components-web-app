<?php

declare(strict_types=1);

namespace App\Database;

use Symfony\Contracts\HttpClient\Exception\ExceptionInterface;
use Symfony\Contracts\HttpClient\HttpClientInterface;

/**
 * Asks Cloud Storage for an object without credentials (#180). A database backup that anyone can read is a leak,
 * whatever the bucket's settings were meant to be.
 */
final class PublicObjectProbe
{
    public function __construct(private readonly HttpClientInterface $httpClient, private readonly string $baseUrl = 'https://storage.googleapis.com')
    {
    }

    /**
     * true: anyone can read it; false: refused without credentials; null: no clear answer.
     */
    public function isPublic(string $bucket, string $object): ?bool
    {
        $url = rtrim($this->baseUrl, '/') . '/' . rawurlencode($bucket) . '/' . implode('/', array_map('rawurlencode', explode('/', $object)));
        try {
            $status = $this->httpClient->request('GET', $url, ['headers' => ['Range' => 'bytes=0-0'], 'max_redirects' => 0])->getStatusCode();
        } catch (ExceptionInterface) {
            return null;
        }

        return match (true) {
            200 === $status, 206 === $status => true,
            401 === $status, 403 === $status => false,
            default => null,
        };
    }
}
