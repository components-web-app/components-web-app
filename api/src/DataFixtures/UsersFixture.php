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
        $this->factory->create($this->adminUsername ?: 'admin', $this->adminPassword ?: 'admin', $this->adminEmail ?: 'hello@cwa.rocks', false, true);
    }
}
