<?php

declare(strict_types=1);

namespace App\DataFixtures;

use App\DataFixtures\Parts\PostFlushScaffoldPartInterface;
use App\DataFixtures\Parts\ScaffoldPartInterface;
use App\DataFixtures\Parts\ScaffoldState;
use Silverback\ApiComponentsBundle\Fixture\AbstractCwaScaffold;
use Silverback\ApiComponentsBundle\Fixture\CwaFixtureBuilder;
use Symfony\Component\DependencyInjection\Attribute\TaggedIterator;

class AppScaffold extends AbstractCwaScaffold
{
    /** @param iterable<ScaffoldPartInterface> $parts */
    public function __construct(
        CwaFixtureBuilder $cwa,
        #[TaggedIterator('cwa.scaffold_part', defaultPriorityMethod: 'getPriority')]
        private readonly iterable $parts,
    ) {
        parent::__construct($cwa);
    }

    public function build(CwaFixtureBuilder $cwa): void
    {
        $state = new ScaffoldState();
        $parts = iterator_to_array($this->parts);

        foreach ($parts as $part) {
            if (!$part instanceof PostFlushScaffoldPartInterface) {
                $part->build($cwa, $state);
            }
        }

        $cwa->flush();

        foreach ($parts as $part) {
            if ($part instanceof PostFlushScaffoldPartInterface) {
                $part->build($cwa, $state);
            }
        }
    }
}
