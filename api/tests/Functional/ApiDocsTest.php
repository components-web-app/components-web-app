<?php

declare(strict_types=1);

namespace App\Tests\Functional;

class ApiDocsTest extends FunctionalTestCase
{
    public function test_the_json_ld_docs_are_served(): void
    {
        static::createClient()->request('GET', '/_api/docs.jsonld', [
            'headers' => ['Accept' => 'application/ld+json'],
        ]);

        self::assertResponseIsSuccessful();
        self::assertStringStartsWith('application/ld+json', (string) self::getClient()->getResponse()->headers->get('content-type'));
        self::assertJsonContains(['@type' => 'ApiDocumentation', 'entrypoint' => '/_api']);
    }
}
