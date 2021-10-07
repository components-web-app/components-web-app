<?php

namespace App\DataFixtures;

use ApiPlatform\Core\Api\IriConverterInterface;
use App\Entity\BlogArticleData;
use App\Entity\HtmlContent;
use App\Lipsum\LipsumContentProvider;
use Doctrine\Common\DataFixtures\DependentFixtureInterface;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Component\Collection;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;
use Silverback\ApiComponentsBundle\Helper\Timestamped\TimestampedDataPersister;

class BlogCollectionPageFixture extends AbstractPageFixture implements DependentFixtureInterface
{
    public const ROUTE_NAME = 'blog-articles-page';
    private IriConverterInterface $iriConverter;

    public function __construct(TimestampedDataPersister $timestampedDataPersister, LipsumContentProvider $lipsumContentProvider, IriConverterInterface $iriConverter)
    {
        $this->iriConverter = $iriConverter;
        parent::__construct($timestampedDataPersister, $lipsumContentProvider);
    }

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
        $collection->setResourceIri($this->iriConverter->getIriFromResourceClass(BlogArticleData::class));
        $manager->persist($collection);

        $componentCollection = $this->createComponentCollection('primary', $page);
        $manager->persist($componentCollection);

        $position = $this->createComponentPosition($componentCollection, $collection, 0);
        $manager->persist($position);

        $componentCollection2 = $this->createComponentCollection( 'secondary', $page);
        $manager->persist($componentCollection2);
        $position2 = $this->createComponentPosition($componentCollection2, $this->getReference('side_html'), 0);
        $manager->persist($position2);

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
