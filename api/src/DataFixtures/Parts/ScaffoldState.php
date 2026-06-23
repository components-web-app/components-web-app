<?php

declare(strict_types=1);

namespace App\DataFixtures\Parts;

use Silverback\ApiComponentsBundle\Fixture\Builder\GroupBuilder;

class ScaffoldState
{
    public ?GroupBuilder $navGroup = null;
    public ?GroupBuilder $homePrimaryGroup = null;
}
