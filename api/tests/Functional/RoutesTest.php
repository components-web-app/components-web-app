<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use Silverback\ApiComponentsBundle\Entity\Core\Route;

class RoutesTest extends FunctionalTestCase
{
    public function test_an_anonymous_visitor_can_list_routes(): void
    {
        $route = new Route();
        $route->setPath('/functional-test')->setName('functional-test');
        // Set by the bundle's API write path, which a direct persist skips.
        $route->setCreatedAt(new \DateTimeImmutable());
        $route->setModifiedAt(new \DateTime());
        $manager = self::getContainer()->get('doctrine')->getManager();
        $manager->persist($route);
        $manager->flush();

        static::createClient()->request('GET', '/_api/_/routes', [
            'headers' => ['Accept' => 'application/ld+json'],
        ]);

        self::assertResponseIsSuccessful();
        self::assertJsonContains(['totalItems' => 1, 'member' => [['path' => '/functional-test']]]);
    }
}
