<?php

namespace App\DataFixtures;

use ApiPlatform\Core\Api\IriConverterInterface;
use App\Entity\BlogArticleData;
use App\Lipsum\LipsumContentProvider;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Component\Collection;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;
use Silverback\ApiComponentsBundle\Helper\Timestamped\TimestampedDataPersister;

class BlogCollectionPageFixture extends AbstractPageFixture
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
        $layout = $this->createLayout('Main Layout', 'primary');
        $manager->persist($layout);
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

        $componentCollection = $this->createComponentCollection($page, 'primary');
        $manager->persist($componentCollection);

        $position = $this->createComponentPosition($componentCollection, $collection, 0);
        $manager->persist($position);

        $route = $this->createRoute('/blog-articles', self::ROUTE_NAME, $page);
        $manager->persist($route);
    }
}
