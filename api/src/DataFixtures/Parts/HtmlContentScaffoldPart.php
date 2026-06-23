<?php

declare(strict_types=1);

namespace App\DataFixtures\Parts;

use App\Entity\HtmlContent;
use Silverback\ApiComponentsBundle\Fixture\CwaFixtureBuilder;
use Silverback\ApiComponentsBundle\Fixture\Placeholder\HtmlContentPlaceholder;

class HtmlContentScaffoldPart implements ScaffoldPartInterface
{
    public function __construct(
        private readonly HtmlContentPlaceholder $placeholderProvider,
    ) {}

    public static function getPriority(): int
    {
        return 70;
    }

    public function build(CwaFixtureBuilder $cwa, ScaffoldState $state): void
    {
        if ($state->homePrimaryGroup === null) {
            return;
        }

        $htmlContent = new HtmlContent();
        $htmlContent->html = $this->placeholderProvider->generate([
            'paragraphs' => 2,
            'includeHeadings' => true,
            'includeLinks' => true,
            'paragraphLength' => HtmlContentPlaceholder::LENGTH_SHORT,
        ]);
        $htmlContent->setPublishedAt(new \DateTime());

        $htmlContentDraft = new HtmlContent();
        $htmlContentDraft->html = $this->placeholderProvider->generate([
            'paragraphs' => 1,
            'paragraphLength' => HtmlContentPlaceholder::LENGTH_MEDIUM,
        ]);
        $htmlContentDraft->setPublishedResource($htmlContent);

        $htmlContentBottom = new HtmlContent();
        $htmlContentBottom->html = $this->placeholderProvider->generate([
            'paragraphs' => 1,
            'includeLinks' => true,
            'paragraphLength' => HtmlContentPlaceholder::LENGTH_MEDIUM,
        ]);
        $htmlContentBottom->setPublishedAt(new \DateTime());

        $state->homePrimaryGroup
            ->add($htmlContent)
            ->add($htmlContentDraft)
            ->add($htmlContentBottom);
    }
}
