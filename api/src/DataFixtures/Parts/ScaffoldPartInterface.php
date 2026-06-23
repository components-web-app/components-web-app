<?php

declare(strict_types=1);

namespace App\DataFixtures\Parts;

use Silverback\ApiComponentsBundle\Fixture\CwaFixtureBuilder;
use Symfony\Component\DependencyInjection\Attribute\AutoconfigureTag;

#[AutoconfigureTag('cwa.scaffold_part')]
interface ScaffoldPartInterface
{
    public function build(CwaFixtureBuilder $cwa, ScaffoldState $state): void;

    public static function getPriority(): int;
}
