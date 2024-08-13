<?php

declare(strict_types=1);


namespace App\DataFixtures;


use ApiPlatform\Api\IriConverterInterface;
use ApiPlatform\Api\UrlGeneratorInterface;
use ApiPlatform\Metadata\GetCollection;
use App\Entity\NavigationLink;
use App\Lipsum\LipsumContentProvider;
use Doctrine\Bundle\FixturesBundle\Fixture;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractComponent;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractPageData;
use Silverback\ApiComponentsBundle\Entity\Core\ComponentGroup;
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
        $manager->persist($layout);
        $manager->flush();
        $componentGroupTop = $this->createComponentGroup( 'top', null, $layout);
        $componentGroupTop->addAllowedComponent($this->iriConverter->getIriFromResource(NavigationLink::class, UrlGeneratorInterface::ABS_PATH, (new GetCollection())->withClass(NavigationLink::class)));

        $this->addNavigationLink($manager, $componentGroupTop, 'Home', '/', HomePageFixture::ROUTE_NAME, 1);
        $this->addNavigationLink($manager, $componentGroupTop, 'Blog', '/blog-articles', BlogCollectionPageFixture::ROUTE_NAME, 2);
        $this->addNavigationLink($manager, $componentGroupTop, 'Form', '/form', FormPageFixture::ROUTE_NAME, 3);

        $manager->persist($componentGroupTop);

        $this->addReference($fixtureRef, $layout);
        return $layout;
    }

    protected function addNavigationLink(ObjectManager $manager, ComponentGroup $collection, string $label, ?string $path, ?string $routeName, int $sort = 0, ?Route $route = null): void
    {
        if (!$route) {
            $route = $this->createRoute($path, $routeName);
            $manager->persist($route);
        }

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

    protected function createComponentGroup(string $reference, ?Page $page = null, ?Layout $layout = null): ComponentGroup
    {
        $ref = $reference;
        if ($page) {
            $ref .= '_' . $this->iriConverter->getIriFromResource($page);
        }
        if ($layout) {
            $ref .= '_' . $this->iriConverter->getIriFromResource($layout);
        }
        $fixtureRef = ComponentGroup::class . '_' . $ref;
        if ($this->hasReference($fixtureRef)) {
            return $this->getReference($fixtureRef);
        }
        $componentGroup = new ComponentGroup();
        $componentGroup
            ->setReference($ref)
            ->setLocation($reference)
        ;
        if ($page) {
            $componentGroup->addPage($page);
        }
        if ($layout) {
            $componentGroup->addLayout($layout);
        }
        $this->timestampedDataPersister->persistTimestampedFields($componentGroup, true);
        $this->addReference($fixtureRef, $componentGroup);
        return $componentGroup;
    }

    protected function createComponentPosition(ComponentGroup $componentGroup, ?AbstractComponent $component, ?int $sortValue = null): ComponentPosition
    {
        $position = new ComponentPosition();
        $position
            ->setComponentGroup($componentGroup)
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
