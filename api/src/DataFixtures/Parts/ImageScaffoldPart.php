<?php

declare(strict_types=1);

namespace App\DataFixtures\Parts;

use App\Entity\Image;
use Silverback\ApiComponentsBundle\Fixture\CwaFixtureBuilder;

class ImageScaffoldPart implements ScaffoldPartInterface
{
    public static function getPriority(): int
    {
        return 60;
    }

    public function build(CwaFixtureBuilder $cwa, ScaffoldState $state): void
    {
        if ($state->homePrimaryGroup === null) {
            return;
        }

        $state->homePrimaryGroup->add(new Image());
    }
}
