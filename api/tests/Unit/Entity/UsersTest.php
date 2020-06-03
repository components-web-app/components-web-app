<?php

/*
 * This file is part of the Silverback API Components Bundle Project
 *
 * (c) Daniel West <daniel@silverback.is>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

declare(strict_types=1);

namespace App\Tests\Unit\Entity;

use PHPUnit\Framework\TestCase;
use App\Entity\AppUser;

class UsersTest extends TestCase
{
    public function test_instanciate_user(): void
    {
        $user = new AppUser();
        $this->assertInstanceOf(AppUser::class, $user);
    }

    public function test_construct(): void
    {
        $user = new AppUser('username');
        $this->assertEquals('username', $user->getUsername()); // previsible (already tested in bundle)
        $this->assertEquals('username', $user->getEmailAddress());
    }

    public function test_set_username(): void
    {
        $user = new AppUser('username');
        $user->setUsername('new_username');
        $this->assertEquals('new_username', $user->getUsername()); // previsible (already tested in bundle)
        $this->assertEquals('new_username', $user->getEmailAddress());

    }
}
