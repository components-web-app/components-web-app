<?php

namespace App\DataFixtures;

use App\Entity\BlogArticleData;
use App\Entity\HtmlContent;
use Doctrine\Common\DataFixtures\DependentFixtureInterface;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;
use Silverback\ApiComponentsBundle\Entity\Core\Page;
use Silverback\ApiComponentsBundle\Entity\Core\Route;
use Silverback\ApiComponentsBundle\Helper\Route\RouteGeneratorInterface;
use Silverback\ApiComponentsBundle\Helper\Timestamped\TimestampedDataPersister;

class BlogArticlesFixture extends AbstractPageFixture implements DependentFixtureInterface
{
    private RouteGeneratorInterface $routeGenerator;

    public function __construct(TimestampedDataPersister $timestampedDataPersister, RouteGeneratorInterface $routeGenerator)
    {
        $this->routeGenerator = $routeGenerator;
        parent::__construct($timestampedDataPersister);
    }

    public function load(ObjectManager $manager): void
    {
        $layout = $this->createLayout('Main Layout', 'primary');
        $manager->persist($layout);
        $page = $this->addArticlePage($manager, $layout);
        $this->addBlogArticles($manager, $page);

        $manager->flush();
    }

    private function addBlogArticles(ObjectManager $manager, Page $page): void
    {
        for($x=0; $x<2; $x++) {
            $htmlContent = new HtmlContent();
            $htmlContent->html = sprintf('<p>Bonjour mon ami %d</p>', $x);
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
        $page = $this->createPage('blog-template', 'PrimaryPageTemplate', $layout);
        $manager->persist($page);

        $componentCollection = $this->createComponentCollection($page, 'primary');
        $manager->persist($componentCollection);

        $position = $this->createComponentPosition($componentCollection, null, 0);
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
