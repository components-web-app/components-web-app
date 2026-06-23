<?php

declare(strict_types=1);

namespace App\DataFixtures\Parts;

use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\IriConverterInterface;
use ApiPlatform\Metadata\UrlGeneratorInterface;
use App\Entity\BlogArticleData;
use App\Entity\HtmlContent;
use Silverback\ApiComponentsBundle\Entity\Component\Collection;
use Silverback\ApiComponentsBundle\Fixture\Builder\PageBuilder;
use Silverback\ApiComponentsBundle\Fixture\CwaFixtureBuilder;
use Silverback\ApiComponentsBundle\Fixture\Placeholder\HtmlContentPlaceholder;

class BlogScaffoldPart implements ScaffoldPartInterface
{
    public function __construct(
        private readonly HtmlContentPlaceholder $placeholderProvider,
        private readonly IriConverterInterface $iriConverter,
    ) {}

    public static function getPriority(): int
    {
        return 50;
    }

    public function build(CwaFixtureBuilder $cwa, ScaffoldState $state): void
    {
        $collection = new Collection();
        $collection->setPerPage(8);
        $collection->setResourceIri(
            $this->iriConverter->getIriFromResource(
                BlogArticleData::class,
                UrlGeneratorInterface::ABS_PATH,
                (new GetCollection())->withClass(BlogArticleData::class)
            )
        );

        $cwa->page('blog-list', 'PrimaryPageTemplate', layout: 'main', route: '/blog-articles', routeName: 'blog-articles-page',
            configure: function (PageBuilder $p) use ($collection) {
                $p->title('Blog')->metaDescription('A sample CWA Blog Articles page using the Collection component');
                $p->group('primary')->add($collection);
            }
        );

        $cwa->page('blog-template', 'PrimaryPageTemplate', layout: 'main', isTemplate: true,
            configure: function (PageBuilder $p) {
                $p->group('primary')
                    ->pageDataPosition(BlogArticleData::class, 'image')
                    ->pageDataPosition(BlogArticleData::class, 'htmlContent');
            }
        );

        for ($i = 0; $i < 3; $i++) {
            $htmlContent = new HtmlContent();
            $htmlContent->html = $this->placeholderProvider->generate([
                'paragraphs' => 2,
                'includeHeadings' => true,
                'paragraphLength' => HtmlContentPlaceholder::LENGTH_SHORT,
            ]);
            $htmlContent->setPublishedAt(new \DateTime());
            $cwa->persist($htmlContent);

            $articleData = new BlogArticleData();
            $articleData->setTitle(sprintf('Blog Article %d', $i + 1))
                ->setMetaDescription(sprintf('A sample CWA blog article — article number %d.', $i + 1));
            $articleData->htmlContent = $htmlContent;

            $cwa->pageData($articleData, template: 'blog-template', route: sprintf('/blog-articles/blog-article-%d', $i + 1));
        }
    }
}
