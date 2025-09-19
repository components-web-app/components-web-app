<?php

namespace App\DataFixtures;

use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\UrlGeneratorInterface;
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
        $layout = $this->createLayout($manager, 'Main Layout', 'CwaLayoutPrimary');
        $this->addBlogCollectionPage($manager, $layout);

        $manager->flush();
    }

    private function addBlogCollectionPage(ObjectManager $manager, Layout $layout): void
    {
        $page = $this->createPage('blog-list', 'PrimaryPageTemplate', $layout);
        $page->setTitle('Blog')->setMetaDescription('A sample CWA Blog Articles page using the Collection component');
        $manager->persist($page);

        $collection = new Collection();
        $collection->setPerPage(8);
        $collection->setResourceIri($this->getIriConverter()->getIriFromResource(BlogArticleData::class, UrlGeneratorInterface::ABS_PATH, (new GetCollection())->withClass(BlogArticleData::class)));
        $manager->persist($collection);

        $componentGroup = $this->createComponentGroup('primary', $page);
        $manager->persist($componentGroup);

        $position = $this->createComponentPosition($componentGroup, $collection, 0);
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
