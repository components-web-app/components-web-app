<?php

declare(strict_types=1);


namespace App\DataFixtures;


use ApiPlatform\Core\Api\IriConverterInterface;
use App\Entity\NavigationLink;
use App\Lipsum\LipsumContentProvider;
use Doctrine\Bundle\FixturesBundle\Fixture;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractComponent;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractPageData;
use Silverback\ApiComponentsBundle\Entity\Core\ComponentCollection;
use Silverback\ApiComponentsBundle\Entity\Core\ComponentPosition;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;
use Silverback\ApiComponentsBundle\Entity\Core\Page;
use Silverback\ApiComponentsBundle\Entity\Core\Route;
use Silverback\ApiComponentsBundle\Helper\Timestamped\TimestampedDataPersister;

/**
 * @author Daniel West <daniel@silverback.is>
 */
abstract class AbstractPageFixture extends Fixture
{
    protected TimestampedDataPersister $timestampedDataPersister;
    protected LipsumContentProvider $lipsumContentProvider;
    protected IriConverterInterface $iriConverter;

    public function __construct(TimestampedDataPersister $timestampedDataPersister, LipsumContentProvider $lipsumContentProvider, IriConverterInterface $iriConverter)
    {
        $this->timestampedDataPersister = $timestampedDataPersister;
        $this->lipsumContentProvider = $lipsumContentProvider;
        $this->iriConverter = $iriConverter;
    }

    protected function createLayout(ObjectManager $manager, string $reference, string $uiComponent): Layout
    {
        $fixtureRef = Layout::class . '_' . $reference;
        if ($this->hasReference($fixtureRef)) {
            return $this->getReference($fixtureRef);
        }
        $layout = new Layout();
        $layout->reference = $reference;
        $layout->uiComponent = $uiComponent;
        $this->timestampedDataPersister->persistTimestampedFields($layout, true);

        $componentCollectionTop = $this->createComponentCollection( 'top', null, $layout);
        $componentCollectionTop->addAllowedComponent($this->iriConverter->getIriFromResourceClass(NavigationLink::class));

        $this->addNavigationLink($manager, $componentCollectionTop, 'Home', '/', HomePageFixture::ROUTE_NAME, 1);
        $this->addNavigationLink($manager, $componentCollectionTop, 'Blog', '/blog-articles', BlogCollectionPageFixture::ROUTE_NAME, 2);
        $this->addNavigationLink($manager, $componentCollectionTop, 'Form', '/form', FormPageFixture::ROUTE_NAME, 3);

        $manager->persist($layout);
        $manager->persist($componentCollectionTop);

        $this->addReference($fixtureRef, $layout);
        return $layout;
    }

    private function addNavigationLink(ObjectManager $manager, ComponentCollection $collection, string $label, string $path, string $routeName, int $sort = 0): void
    {
        $route = $this->createRoute($path, $routeName);
        $manager->persist($route);

        $navigationLink = new NavigationLink();
        $navigationLink->label = $label;
        $navigationLink->route = $route;
        $navigationLink->setPublishedAt(new \DateTime());
        $position = $this->createComponentPosition($collection, $navigationLink, $sort);
        $manager->persist($navigationLink);
        $manager->persist($position);
    }

    protected function persistArray(ObjectManager $manager, $array)
    {
        foreach ($array as $item) {
            $manager->persist($item);
        }
    }

    protected function createPage(string $reference, string $uiComponent, Layout $layout, bool $isTemplate = false): Page
    {
        $fixtureRef = Page::class . '_' . $reference;
        if ($this->hasReference($fixtureRef)) {
            return $this->getReference($fixtureRef);
        }
        $page = new Page();
        $page->isTemplate = $isTemplate;
        $page->reference = $reference;
        $page->uiComponent = $uiComponent;
        $page->layout = $layout;
        $this->timestampedDataPersister->persistTimestampedFields($page, true);
        $this->addReference($fixtureRef, $page);
        return $page;
    }

    protected function createComponentCollection(string $reference, ?Page $page = null, ?Layout $layout = null): ComponentCollection
    {
        $ref = $reference;
        if ($page) {
            $ref .= '_' . $page->reference;
        }
        if ($layout) {
            $ref .= '_' . $layout->reference;
        }
        $fixtureRef = ComponentCollection::class . '_' . $ref;
        if ($this->hasReference($fixtureRef)) {
            return $this->getReference($fixtureRef);
        }
        $componentCollection = new ComponentCollection();
        $componentCollection
            ->setReference($ref)
            ->setLocation($reference)
        ;
        if ($page) {
            $componentCollection->addPage($page);
        }
        if ($layout) {
            $componentCollection->addLayout($layout);
        }
        $this->timestampedDataPersister->persistTimestampedFields($componentCollection, true);
        $this->addReference($fixtureRef, $componentCollection);
        return $componentCollection;
    }

    protected function createComponentPosition(ComponentCollection $componentCollection, ?AbstractComponent $component, ?int $sortValue = null): ComponentPosition
    {
        $position = new ComponentPosition();
        $position
            ->setComponentCollection($componentCollection)
            ->setSortValue($sortValue);
        if ($component) {
            $position->setComponent($component);
        }
        $this->timestampedDataPersister->persistTimestampedFields($position, true);
        return $position;
    }

    protected function createRoute(string $path, string $name, ?Page $page = null, ?AbstractPageData $pageData = null): Route
    {
        $fixtureRef = Route::class . '_' . $name;
        if ($this->hasReference($fixtureRef)) {
            $route = $this->getReference($fixtureRef);
        } else {
            $route = new Route();
            $this->timestampedDataPersister->persistTimestampedFields($route, true);
            $this->addReference($fixtureRef, $route);
        }
        $route
            ->setPath($path)
            ->setName($name)
        ;
        if ($page) {
            $route->setPage($page);
        }
        if ($pageData) {
            $route->setPageData($pageData);
        }
        return $route;
    }
}
