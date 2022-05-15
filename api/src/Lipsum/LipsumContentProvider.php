<?php

declare(strict_types=1);

namespace App\Lipsum;

use Symfony\Component\HttpClient\Exception\TimeoutException;
use Symfony\Component\HttpClient\Exception\TransportException;
use Symfony\Contracts\HttpClient\Exception\HttpExceptionInterface;
use Symfony\Contracts\HttpClient\HttpClientInterface;

/**
 * @author Daniel West <daniel@silverback.is>
 */
class LipsumContentProvider
{
    private HttpClientInterface $client;
    private array $context;
    private array $clientContext;

    public function __construct(HttpClientInterface $client, ?array $context = null, array $clientContext = [])
    {
        $this->client = $client;
        $this->context = $context ?: [
            '5',
            'medium',
            'headers',
            'code',
            'decorate',
            'link',
            'bq',
            'ul',
            'ol'
        ];
        $this->clientContext = array_merge([
            // 'connect_timeout' => 3,
            // 'read_timeout' => 2,
            'timeout' => 5
        ], $clientContext);
    }

    public function generate(?array $context = null, array $clientContext = [], bool $throw = false): string
    {
        $context = $context ?: $this->context;
        $clientContext = array_merge($this->clientContext, $clientContext);

        $url = 'https://loripsum.net/api/' . implode('/', $context);

        try {
            $res = $this->client->request(
                'GET',
                $url,
                $clientContext
            );
            $content = $res->getContent();
        } catch (HttpExceptionInterface|TimeoutException|TransportException $e) {
            if ($throw) {
                throw $e;
            }
            $content = vsprintf(
                '<p><b>Request Exception</b>: %s<br/><small><a href="%s">%s</a></small></p>',
                [
                    $e->getMessage(),
                    $e->getCode(),
                    $url,
                    $url
                ]
            );
        }
        return $content;
    }
}
