<?php

namespace App\DataFixtures;

use ApiPlatform\Api\UrlGeneratorInterface;
use ApiPlatform\Metadata\GetCollection;
use App\Entity\BlogArticleData;
use Doctrine\Common\DataFixtures\DependentFixtureInterface;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Component\Collection;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;

class BlogCollectionPageFixture extends AbstractPageFixture implements DependentFixtureInterface
{
    public const ROUTE_NAME = 'blog-articles-page';

    public function load(ObjectManager $manager): void
    {
        $layout = $this->createLayout($manager, 'Main Layout', 'primary');
        $this->addBlogCollectionPage($manager, $layout);

        $manager->flush();
    }

    private function addBlogCollectionPage(ObjectManager $manager, Layout $layout): void
    {
        $page = $this->createPage('blog-list', 'PrimaryPageTemplate', $layout);
        $page->setTitle('Blog')->setMetaDescription('A sample CWA Blog Articles page using the Collection component');
        $manager->persist($page);

        $collection = new Collection();
        $collection->setResourceIri($this->iriConverter->getIriFromResource(BlogArticleData::class, UrlGeneratorInterface::ABS_PATH, (new GetCollection())->withClass(BlogArticleData::class)));
        $manager->persist($collection);

        $componentCollection = $this->createComponentCollection('primary', $page);
        $manager->persist($componentCollection);

        $position = $this->createComponentPosition($componentCollection, $collection, 0);
        $manager->persist($position);

        $route = $this->createRoute('/blog-articles', self::ROUTE_NAME, $page);
        $manager->persist($route);
    }

    public function getDependencies(): array
    {
        return [
            HomePageFixture::class
        ];
    }
}
