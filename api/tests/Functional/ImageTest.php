<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use App\Entity\Image;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Lexik\Bundle\JWTAuthenticationBundle\Services\JWTTokenManagerInterface;

class ImageTest extends FunctionalTestCase
{
    public function test_an_image_cannot_be_published_without_a_file(): void
    {
        $image = $this->persistDraftImage(null);

        $this->publish($image);

        self::assertResponseStatusCodeSame(422);
        self::assertJsonContains(['violations' => [['propertyPath' => 'file']]]);
    }

    public function test_an_image_with_a_stored_file_can_be_published(): void
    {
        $image = $this->persistDraftImage('photo-0123abcd.jpg');

        $this->publish($image);

        self::assertResponseIsSuccessful();
    }

    private function persistDraftImage(?string $filename): Image
    {
        $image = new Image();
        if (null !== $filename) {
            $image->setFilename($filename);
        }
        $manager = $this->manager();
        $manager->persist($image);
        $manager->flush();

        return $image;
    }

    private function publish(Image $image): void
    {
        $admin = new User('admin', 'admin@example.com', true, ['ROLE_SUPER_ADMIN']);
        // Set by the bundle's API write path, which a direct persist skips.
        $admin->setCreatedAt(new \DateTimeImmutable());
        $admin->setModifiedAt(new \DateTime());
        $manager = $this->manager();
        $manager->persist($admin);
        $manager->flush();
        $token = self::getContainer()->get(JWTTokenManagerInterface::class)->create($admin);

        static::createClient()->request('PATCH', '/_api/component/images/'.$image->getId(), [
            'headers' => [
                'Accept' => 'application/ld+json',
                'Content-Type' => 'application/merge-patch+json',
                'Authorization' => 'Bearer '.$token,
            ],
            'json' => ['publishedAt' => (new \DateTimeImmutable('-1 minute'))->format(\DATE_ATOM)],
        ]);
    }

    private function manager(): EntityManagerInterface
    {
        $manager = self::getContainer()->get('doctrine')->getManager();
        \assert($manager instanceof EntityManagerInterface);

        return $manager;
    }
}
