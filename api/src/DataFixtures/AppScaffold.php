<?php

declare(strict_types=1);

namespace App\DataFixtures;

use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\IriConverterInterface;
use ApiPlatform\Metadata\UrlGeneratorInterface;
use App\Entity\BlogArticleData;
use App\Entity\HtmlContent;
use App\Entity\Image;
use App\Entity\NavigationLink;
use App\Entity\NestedPageData;
use App\Form\ExampleFormType;
use Silverback\ApiComponentsBundle\Entity\Component\Collection;
use Silverback\ApiComponentsBundle\Entity\Component\Form;
use Silverback\ApiComponentsBundle\Fixture\Placeholder\HtmlContentPlaceholder;
use Silverback\ApiComponentsBundle\Fixture\AbstractCwaScaffold;
use Silverback\ApiComponentsBundle\Fixture\Builder\PageBuilder;
use Silverback\ApiComponentsBundle\Fixture\CwaFixtureBuilder;

class AppScaffold extends AbstractCwaScaffold
{
    public function __construct(
        CwaFixtureBuilder $cwa,
        private readonly HtmlContentPlaceholder $placeholderProvider,
        private readonly IriConverterInterface $iriConverter,
    ) {
        parent::__construct($cwa);
    }

    public function build(CwaFixtureBuilder $cwa): void
    {
        $navGroup = $cwa->layout('main', 'CwaLayoutPrimary')
            ->group('top', allow: [NavigationLink::class]);

        $this->addHomePage($cwa);
        $this->addBlogPages($cwa);
        $this->addNestedTopicPages($cwa);
        $this->addFormPage($cwa);

        $cwa->flush();

        $homeLink = new NavigationLink();
        $homeLink->label = 'Home';
        $homeLink->route = $cwa->getRoute('home-page');
        $homeLink->setPublishedAt(new \DateTime());

        $blogLink = new NavigationLink();
        $blogLink->label = 'Blog';
        $blogLink->route = $cwa->getRoute('blog-articles-page');
        $blogLink->setPublishedAt(new \DateTime());

        $topic1Link = new NavigationLink();
        $topic1Link->label = 'Topic 1';
        $topic1Link->route = $cwa->getRoute('topic-1');
        $topic1Link->setPublishedAt(new \DateTime());

        $formLink = new NavigationLink();
        $formLink->label = 'Form Demo';
        $formLink->route = $cwa->getRoute('form-page');
        $formLink->setPublishedAt(new \DateTime());

        $navGroup->add($homeLink)->add($blogLink)->add($topic1Link)->add($formLink);
    }

    private function addHomePage(CwaFixtureBuilder $cwa): void
    {
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

        $cwa->page('home', 'PrimaryPageTemplate', layout: 'main', route: '/', routeName: 'home-page',
            configure: function (PageBuilder $p) use ($htmlContent, $htmlContentDraft, $htmlContentBottom) {
                $p->title('Welcome to CWA')->metaDescription('A demo CWA website');
                $p->group('primary')
                    ->add($htmlContent)
                    ->add($htmlContentDraft)
                    ->add(new Image())
                    ->add($htmlContentBottom);
            }
        );
    }

    private function addBlogPages(CwaFixtureBuilder $cwa): void
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

        for ($i = 0; $i < 10; $i++) {
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

    private function addNestedTopicPages(CwaFixtureBuilder $cwa): void
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

        $topicBuilder->onRoutesCreated(function (array $childBuilders) use ($intro) {
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

    private function addFormPage(CwaFixtureBuilder $cwa): void
    {
        $formComponent = new Form();
        $formComponent->formType = ExampleFormType::class;

        $cwa->page('form', 'PrimaryPageTemplate', layout: 'main', route: '/form', routeName: 'form-page',
            configure: function (PageBuilder $p) use ($formComponent) {
                $p->title('Form Demo')->metaDescription('A demo form showing all Symfony form field types with CWA form composables');
                $p->group('primary')->add($formComponent);
            }
        );
    }
}
