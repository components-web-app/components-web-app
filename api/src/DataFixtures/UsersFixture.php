<?php

declare(strict_types=1);

namespace App\DataFixtures;

use Doctrine\Bundle\FixturesBundle\Fixture;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Factory\User\UserFactory;
use Symfony\Component\DependencyInjection\Attribute\Autowire;

/**
 * @author Daniel West <daniel@silverback.is>
 */
class UsersFixture extends Fixture
{

    public function __construct(
        private readonly UserFactory $factory,
        #[Autowire(env: 'default::ADMIN_USERNAME')]
        private readonly ?string $adminUsername = null,
        #[Autowire(env: 'default::ADMIN_PASSWORD')]
        private readonly ?string $adminPassword = null,
        #[Autowire(env: 'default::ADMIN_EMAIL')]
        private readonly ?string $adminEmail = null
    ) {
    }

    public function load(ObjectManager $manager): void
    {
        // overwrite: true is required for idempotency — without it the factory never
        // looks up the existing user and every re-run persists another admin with the
        // same username, which makes login 500 (NonUniqueResultException). The columns
        // are not unique at the database level, so nothing else prevents it.
        // Trade-off: the admin password is reset to ADMIN_PASSWORD on every run.
        $this->factory->create(
            $this->adminUsername ?: 'admin',
            $this->adminPassword ?: 'admin',
            $this->adminEmail ?: 'hello@cwa.rocks',
            superAdmin: true,
            overwrite: true,
        );
    }
}
