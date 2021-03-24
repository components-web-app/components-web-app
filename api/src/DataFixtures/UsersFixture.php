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
    private UserFactory $factory;

    public function __construct(UserFactory $factory)
    {
        $this->factory = $factory;
    }

    public function load(ObjectManager $manager)
    {
        $this->factory->create('admin', 'admin', 'hello@cwa.rocks', false, true);
    }
}
