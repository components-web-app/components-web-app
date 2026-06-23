<?php

declare(strict_types=1);

namespace App\DataFixtures\Parts;

use App\Entity\Title;
use Silverback\ApiComponentsBundle\Fixture\Builder\PageBuilder;
use Silverback\ApiComponentsBundle\Fixture\CwaFixtureBuilder;

class CoreScaffoldPart implements ScaffoldPartInterface
{
    public static function getPriority(): int
    {
        return 100;
    }

    public function build(CwaFixtureBuilder $cwa, ScaffoldState $state): void
    {
        $state->navGroup = $cwa->layout('main', 'CwaLayoutPrimary')
            ->group('top');

        $title = new Title();
        $title->title = 'Welcome to CWA';
        $title->setPublishedAt(new \DateTime());

        $cwa->page('home', 'PrimaryPageTemplate', layout: 'main', route: '/', routeName: 'home-page',
            configure: function (PageBuilder $p) use ($title, $state) {
                $p->title('Welcome to CWA')->metaDescription('A demo CWA website');
                $state->homePrimaryGroup = $p->group('primary');
                $state->homePrimaryGroup->add($title);
            }
        );
    }
}
