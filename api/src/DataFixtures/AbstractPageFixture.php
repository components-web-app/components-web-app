<?php

declare(strict_types=1);


namespace App\DataFixtures;


use Doctrine\Bundle\FixturesBundle\Fixture;
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

    public function __construct(TimestampedDataPersister $timestampedDataPersister)
    {
        $this->timestampedDataPersister = $timestampedDataPersister;
    }

    protected function createLayout(string $reference, string $uiComponent): Layout
    {
        $fixtureRef = Layout::class . '_' . $reference;
        if ($this->hasReference($fixtureRef)) {
            return $this->getReference($fixtureRef);
        }
        $layout = new Layout();
        $layout->reference = $reference;
        $layout->uiComponent = $uiComponent;
        $this->timestampedDataPersister->persistTimestampedFields($layout, true);
        $this->addReference($fixtureRef, $layout);
        return $layout;
    }

    protected function createPage(string $reference, string $uiComponent, Layout $layout): Page
    {
        $fixtureRef = Page::class . '_' . $reference;
        if ($this->hasReference($fixtureRef)) {
            return $this->getReference($fixtureRef);
        }
        $page = new Page();
        $page->reference = $reference;
        $page->uiComponent = $uiComponent;
        $page->layout = $layout;
        $this->timestampedDataPersister->persistTimestampedFields($page, true);
        $this->addReference($fixtureRef, $page);
        return $page;
    }

    protected function createComponentCollection(Page $page, string $reference): ComponentCollection
    {
        $fixtureRef = ComponentCollection::class . '_' . $page->reference . '_' . $reference;
        if ($this->hasReference($fixtureRef)) {
            return $this->getReference($fixtureRef);
        }
        $componentCollection = new ComponentCollection();
        $componentCollection->setReference($page->reference . '_' . $reference)->addPage($page);
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
            return $this->getReference($fixtureRef);
        }
        $route = new Route();
        $route
            ->setPath($path)
            ->setName($name)
            ->setPage($page)
            ->setPageData($pageData)
        ;
        $this->timestampedDataPersister->persistTimestampedFields($route, true);
        $this->addReference($fixtureRef, $route);
        return $route;
    }
}
