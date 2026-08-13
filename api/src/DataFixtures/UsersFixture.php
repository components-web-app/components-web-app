<?php

declare(strict_types=1);

namespace App\DataFixtures;

use Doctrine\Bundle\FixturesBundle\Fixture;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Factory\User\UserFactory;

/**
 * @author Daniel West <daniel@silverback.is>
 */
class UsersFixture extends Fixture
{

    public function __construct(
        private readonly UserFactory $factory,
        private readonly ?string $adminUsername = null,
        private readonly ?string $adminPassword = null,
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
