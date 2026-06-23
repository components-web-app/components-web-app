<?php

declare(strict_types=1);

namespace App\DataFixtures\Parts;

use App\Entity\HtmlContent;
use App\Entity\NestedPageData;
use Silverback\ApiComponentsBundle\Fixture\Builder\PageBuilder;
use Silverback\ApiComponentsBundle\Fixture\Builder\PageDataBuilder;
use Silverback\ApiComponentsBundle\Fixture\CwaFixtureBuilder;
use Silverback\ApiComponentsBundle\Fixture\Placeholder\HtmlContentPlaceholder;

class NestedPagesScaffoldPart implements ScaffoldPartInterface
{
    public function __construct(
        private readonly HtmlContentPlaceholder $placeholderProvider,
    ) {}

    public static function getPriority(): int
    {
        return 40;
    }

    public function build(CwaFixtureBuilder $cwa, ScaffoldState $state): void
    {
        $cwa->page('nested-topic-template', 'NestedTopicTemplate', layout: 'main', isTemplate: true,
            configure: function (PageBuilder $p) {
                $p->group('primary')->pageDataPosition(NestedPageData::class, 'introContent');
            }
        );

        $chapters = [
            ['title' => 'Chapter One'],
            ['title' => 'Chapter Two'],
        ];

        $intro = new HtmlContent();
        $intro->setPublishedAt(new \DateTime());
        $cwa->persist($intro);

        $topicPageData = new NestedPageData();
        $topicPageData->setTitle('Topic 1')->setMetaDescription('Nested topic 1 demonstrating static child pages');
        $topicPageData->introContent = $intro;

        $topicBuilder = $cwa->pageData($topicPageData, template: 'nested-topic-template', routeName: 'topic-1');

        $topicBuilder->nested(function (CwaFixtureBuilder $child) use ($chapters) {
            foreach ($chapters as $j => $chapter) {
                $htmlContent = new HtmlContent();
                $htmlContent->html = sprintf(
                    '<p><strong>%s</strong> — a static child <code>Page</code> of Topic 1\'s <code>NestedPageData</code>. '
                    . 'The topic template renders at depth 0; this page renders at depth 1 via <code>&lt;CwaPage /&gt;</code>.</p>',
                    $chapter['title']
                );
                $htmlContent->setPublishedAt(new \DateTime());

                $child->page(
                    sprintf('topic-1-chapter-%d', $j + 1),
                    'NestedSubPageTemplate',
                    layout: 'main',
                    configure: function (PageBuilder $p) use ($chapter, $htmlContent) {
                        $p->title($chapter['title']);
                        $p->group('primary')->add($htmlContent);
                    }
                );
            }
        });

        $topicBuilder->onRoutesCreated(function (array $childBuilders) use ($intro, $topicPageData) {
            if (!empty($childBuilders) && null !== $topicPageData->getRoute()) {
                $topicPageData->getRoute()->setRedirect($childBuilders[0]->getRoute());
            }

            $links = implode(' | ', array_map(
                fn(PageBuilder $b) => sprintf('<a href="%s">%s</a>', $b->getRoute()->getPath(), $b->getPage()->getTitle()),
                $childBuilders
            ));
            $intro->html = sprintf(
                '<p>Introduction to Topic 1.</p><p>Chapters: %s</p><p>Navigate to a child URL to see nested rendering.</p>',
                $links
            );
        });
    }
}
