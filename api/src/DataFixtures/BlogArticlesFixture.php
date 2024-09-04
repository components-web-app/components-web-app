<?php

namespace App\DataFixtures;

use ApiPlatform\Api\IriConverterInterface;
use App\Entity\BlogArticleData;
use App\Entity\HtmlContent;
use App\Entity\NavigationLink;
use App\Lipsum\LipsumContentProvider;
use Doctrine\Common\DataFixtures\DependentFixtureInterface;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Core\ComponentGroup;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;
use Silverback\ApiComponentsBundle\Entity\Core\Page;
use Silverback\ApiComponentsBundle\Entity\Core\Route;
use Silverback\ApiComponentsBundle\Helper\Route\RouteGeneratorInterface;
use Silverback\ApiComponentsBundle\Helper\Timestamped\TimestampedDataPersister;

class BlogArticlesFixture extends AbstractPageFixture implements DependentFixtureInterface
{
    private RouteGeneratorInterface $routeGenerator;

    public function __construct(TimestampedDataPersister $timestampedDataPersister, LipsumContentProvider $lipsumContentProvider, IriConverterInterface $iriConverter, RouteGeneratorInterface $routeGenerator)
    {
        $this->routeGenerator = $routeGenerator;
        parent::__construct($timestampedDataPersister, $lipsumContentProvider, $iriConverter);
    }

    public function load(ObjectManager $manager): void
    {
        $layout = $this->createLayout($manager, 'Main Layout', 'CwaLayoutPrimary');
        $page = $this->addArticlePage($manager, $layout);

        $layoutGroup = $layout->getComponentGroups()->first();
//        $navigationLink = new NavigationLink();
//        $navigationLink->label = 'Blog Template';
//        $navigationLink->rawPath = $this->iriConverter->getIriFromResource($page);
//        $navigationLink->setPublishedAt(new \DateTime());
//        $position = $this->createComponentPosition($layoutGroup, $navigationLink, 5);
//        $manager->persist($navigationLink);
//        $manager->persist($position);

        $this->addBlogArticles($manager, $page, $layoutGroup);

        $manager->flush();
    }

    private function addBlogArticles(ObjectManager $manager, Page $page, ComponentGroup $layoutComponentGroup): void
    {
        for($x=0; $x<10; $x++) {
            $htmlContent = new HtmlContent();
            $htmlContent->html = sprintf('<p>Bonjour mon ami %d</p>', $x);
            $htmlContent->setPublishedAt(new \DateTime());
            $manager->persist($htmlContent);

            $articleData = new BlogArticleData();
            $articleData
                ->setTitle(sprintf('Blog Article %s', $x))
                ->setMetaDescription(strip_tags($htmlContent->html))
            ;
            $articleData->htmlContent = $htmlContent;
            $articleData->page = $page;
            $this->timestampedDataPersister->persistTimestampedFields($articleData, true);
            $manager->persist($articleData);

            $articleData->setParentRoute(
                $this->getReference(sprintf(Route::class . '_%s', BlogCollectionPageFixture::ROUTE_NAME))
            );
            $route = $this->routeGenerator->create($articleData);
            $manager->persist($route);
        }
    }

    private function addArticlePage(ObjectManager $manager, Layout $layout): Page
    {
        $page = $this->createPage('blog-template', 'PrimaryPageTemplate', $layout, true);
        $manager->persist($page);

        $this->addReference('blog_template', $page);

        $componentGroup = $this->createComponentGroup('primary', $page);
        $manager->persist($componentGroup);

        $htmlContent = new HtmlContent();
        $htmlContent->html = sprintf('<p>Placeholder content for when editing a template. This component will be replaced by the property `htmlContent` in page data.</p>');
        $manager->persist($htmlContent);

        $position = $this->createComponentPosition($componentGroup, null, 0);
        $position->setPageDataProperty('image');
        $manager->persist($position);

        $position = $this->createComponentPosition($componentGroup, null, 1);
        $position->setPageDataProperty('htmlContent');
        $manager->persist($position);

        return $page;
    }

    public function getDependencies(): array
    {
        return [
            BlogCollectionPageFixture::class
        ];
    }
}
