<?php

declare(strict_types=1);

namespace App\DataFixtures\Parts;

use App\Entity\NavigationLink;
use Silverback\ApiComponentsBundle\Fixture\CwaFixtureBuilder;

class NavigationScaffoldPart implements PostFlushScaffoldPartInterface
{
    public static function getPriority(): int
    {
        return 10;
    }

    public function build(CwaFixtureBuilder $cwa, ScaffoldState $state): void
    {
        if ($state->navGroup === null) {
            return;
        }

        $routeLinks = [
            'home-page' => 'Home',
            'blog-articles-page' => 'Blog',
            'topic-1' => 'Topics',
            'form-page' => 'Form Demo',
        ];

        foreach ($routeLinks as $routeName => $label) {
            try {
                $route = $cwa->getRoute($routeName);
            } catch (\Throwable) {
                continue;
            }

            $link = new NavigationLink();
            $link->label = $label;
            $link->route = $route;
            $link->setPublishedAt(new \DateTime());

            $state->navGroup->add($link);
        }
    }
}
