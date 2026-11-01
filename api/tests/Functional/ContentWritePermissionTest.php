<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use App\Entity\Title;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Lexik\Bundle\JWTAuthenticationBundle\Services\JWTTokenManagerInterface;
use PHPUnit\Framework\Attributes\DataProvider;
use Symfony\Contracts\HttpClient\ResponseInterface;

/**
 * Only admins write CWA content (#228): publishable.permission in silverback_api_components.yaml.
 * A signed-in user without ROLE_ADMIN (registration, a members area) gets a 403 on every write.
 */
class ContentWritePermissionTest extends FunctionalTestCase
{
    /** @return iterable<string, array{string, array<string, mixed>}> */
    public static function creates(): iterable
    {
        // {layout}, {page}, {group} and {title} are IRIs an admin creates first (references()).
        yield 'component' => ['/_api/component/titles', ['title' => 'Hello']];
        yield 'layout' => ['/_api/_/layouts', ['reference' => 'layout-228', 'uiComponent' => 'Primary']];
        yield 'page' => ['/_api/_/pages', ['reference' => 'page-228', 'isTemplate' => false, 'uiComponent' => 'Primary', 'layout' => '{layout}']];
        yield 'route' => ['/_api/_/routes', ['path' => '/route-228', 'name' => 'route-228', 'page' => '{page}']];
        yield 'component group' => ['/_api/_/component_groups', ['reference' => 'group-228', 'location' => 'primary']];
        yield 'component position' => ['/_api/_/component_positions', ['componentGroup' => '{group}', 'component' => '{title}']];
    }

    /** @param array<string, mixed> $body */
    #[DataProvider('creates')]
    public function test_a_user_cannot_create_content(string $path, array $body): void
    {
        $body = $this->references($body);
        $this->send('POST', $path, $this->token('member', []), $body);

        self::assertResponseStatusCodeSame(403);
    }

    /** @param array<string, mixed> $body */
    #[DataProvider('creates')]
    public function test_an_admin_can_create_content(string $path, array $body): void
    {
        $body = $this->references($body);
        $this->send('POST', $path, $this->token('admin', ['ROLE_SUPER_ADMIN']), $body);

        self::assertResponseStatusCodeSame(201);
    }

    public function test_a_user_cannot_change_or_delete_a_component(): void
    {
        $iri = '/_api/component/titles/'.$this->persistTitle()->getId();
        $token = $this->token('member', []);

        $this->send('PATCH', $iri, $token, ['title' => 'Changed']);
        self::assertResponseStatusCodeSame(403);

        $this->send('DELETE', $iri, $token);
        self::assertResponseStatusCodeSame(403);
    }

    public function test_an_admin_can_change_and_delete_a_component(): void
    {
        $iri = '/_api/component/titles/'.$this->persistTitle()->getId();
        $token = $this->token('admin', ['ROLE_SUPER_ADMIN']);

        $this->send('PATCH', $iri, $token, ['title' => 'Changed']);
        self::assertResponseIsSuccessful();

        $this->send('DELETE', $iri, $token);
        self::assertResponseStatusCodeSame(204);
    }

    /**
     * @param array<string, mixed> $body
     *
     * @return array<string, mixed>
     */
    private function references(array $body): array
    {
        $needed = array_intersect(['{layout}', '{page}', '{group}', '{title}'], $body);
        if (!$needed) {
            return $body;
        }
        $admin = $this->token('setup', ['ROLE_SUPER_ADMIN']);
        $create = [
            '{layout}' => ['/_api/_/layouts', ['reference' => 'ref-layout', 'uiComponent' => 'Primary']],
            '{page}' => ['/_api/_/pages', ['reference' => 'ref-page', 'isTemplate' => false, 'uiComponent' => 'Primary', 'layout' => '{layout}']],
            '{group}' => ['/_api/_/component_groups', ['reference' => 'ref-group', 'location' => 'primary']],
            '{title}' => ['/_api/component/titles', ['title' => 'Ref']],
        ];
        foreach ($needed as $placeholder) {
            [$path, $refBody] = $create[$placeholder];
            $refBody = $this->references($refBody);
            $iri = $this->send('POST', $path, $admin, $refBody)->toArray()['@id'];
            $body = array_map(fn ($v) => $v === $placeholder ? $iri : $v, $body);
        }

        return $body;
    }

    /** @param array<string, mixed>|null $body */
    private function send(string $method, string $path, string $token, ?array $body = null): ResponseInterface
    {
        $options = ['headers' => [
            'Accept' => 'application/ld+json',
            'Content-Type' => 'PATCH' === $method ? 'application/merge-patch+json' : 'application/ld+json',
            'Authorization' => 'Bearer '.$token,
        ]];
        if (null !== $body) {
            $options['json'] = $body;
        }

        return static::createClient()->request($method, $path, $options);
    }

    /** @param list<string> $roles */
    private function token(string $username, array $roles): string
    {
        $user = new User($username, $username.'@example.com', true, $roles);
        // Set by the bundle's API write path, which a direct persist skips.
        $user->setCreatedAt(new \DateTimeImmutable());
        $user->setModifiedAt(new \DateTime());
        $manager = $this->manager();
        $manager->persist($user);
        $manager->flush();

        return self::getContainer()->get(JWTTokenManagerInterface::class)->create($user);
    }

    private function persistTitle(): Title
    {
        $title = new Title();
        $title->title = 'Hello';
        $manager = $this->manager();
        $manager->persist($title);
        $manager->flush();

        return $title;
    }

    private function manager(): EntityManagerInterface
    {
        $manager = self::getContainer()->get('doctrine')->getManager();
        \assert($manager instanceof EntityManagerInterface);

        return $manager;
    }
}
