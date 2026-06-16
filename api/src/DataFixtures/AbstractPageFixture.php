<?php

declare(strict_types=1);


namespace App\DataFixtures;

use ApiPlatform\Metadata\IriConverterInterface;
use ApiPlatform\Metadata\UrlGeneratorInterface;
use ApiPlatform\Metadata\GetCollection;
use App\Entity\NavigationLink;
use App\PlaceholderProvider\CwaPlaceholderProvider;
use Doctrine\Bundle\FixturesBundle\Fixture;
use Doctrine\Persistence\ObjectManager;
use Psr\Container\ContainerInterface;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractComponent;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractPageData;
use Silverback\ApiComponentsBundle\Entity\Core\ComponentGroup;
use Silverback\ApiComponentsBundle\Entity\Core\ComponentPosition;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;
use Silverback\ApiComponentsBundle\Entity\Core\Page;
use Silverback\ApiComponentsBundle\Entity\Core\Route;
use Silverback\ApiComponentsBundle\Helper\Timestamped\TimestampedDataPersister;
use Symfony\Contracts\Service\ServiceSubscriberInterface;

/**
 * @author Daniel West <daniel@silverback.is>
 */
abstract class AbstractPageFixture extends Fixture implements ServiceSubscriberInterface
{
    public function __construct(
        protected ContainerInterface $container
    ) {}

    protected function getTimestampedDataPersister(): TimestampedDataPersister {
        return $this->container->get(TimestampedDataPersister::class);
    }

    protected function getIriConverter(): IriConverterInterface {
        return $this->container->get(IriConverterInterface::class);
    }

    protected function getCwaPlaceholderProvider(): CwaPlaceholderProvider {
        return $this->container->get(CwaPlaceholderProvider::class);
    }

    protected function createLayout(ObjectManager $manager, string $reference, string $uiComponent): Layout
    {
        $fixtureRef = Layout::class . '_' . $reference;
        if ($this->hasReference($fixtureRef, Layout::class)) {
            return $this->getReference($fixtureRef, Layout::class);
        }
        $layout = new Layout();
        $layout->reference = $reference;
        $layout->uiComponent = $uiComponent;
        $this->getTimestampedDataPersister()->persistTimestampedFields($layout, true);
        $manager->persist($layout);
        $manager->flush();
        $componentGroupTop = $this->createComponentGroup( 'top', null, $layout);
        $componentGroupTop->addAllowedComponent($this->getIriConverter()->getIriFromResource(NavigationLink::class, UrlGeneratorInterface::ABS_PATH, (new GetCollection())->withClass(NavigationLink::class)));

        $this->addNavigationLink($manager, $componentGroupTop, 'Home', '/', HomePageFixture::ROUTE_NAME, 1);
        $this->addNavigationLink($manager, $componentGroupTop, 'Blog', '/blog-articles', BlogCollectionPageFixture::ROUTE_NAME, 2);
        // $this->addNavigationLink($manager, $componentGroupTop, 'Form', '/form', FormPageFixture::ROUTE_NAME, 3);

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
        if ($this->hasReference($fixtureRef, Page::class)) {
            return $this->getReference($fixtureRef, Page::class);
        }
        $page = new Page();
        $page->isTemplate = $isTemplate;
        $page->reference = $reference;
        $page->uiComponent = $uiComponent;
        $page->layout = $layout;
        $this->getTimestampedDataPersister()->persistTimestampedFields($page, true);
        $this->addReference($fixtureRef, $page);
        return $page;
    }

    protected function createComponentGroup(string $reference, ?Page $page = null, ?Layout $layout = null): ComponentGroup
    {
        $ref = $reference;
        if ($page) {
            $ref .= '_' . $this->getIriConverter()->getIriFromResource($page);
        }
        if ($layout) {
            $ref .= '_' . $this->getIriConverter()->getIriFromResource($layout);
        }
        $fixtureRef = ComponentGroup::class . '_' . $ref;
        if ($this->hasReference($fixtureRef, ComponentGroup::class)) {
            return $this->getReference($fixtureRef, ComponentGroup::class);
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
        $this->getTimestampedDataPersister()->persistTimestampedFields($componentGroup, true);
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
        $this->getTimestampedDataPersister()->persistTimestampedFields($position, true);
        return $position;
    }

    protected function createRoute(string $path, string $name, ?Page $page = null, ?AbstractPageData $pageData = null): Route
    {
        $fixtureRef = Route::class . '_' . $name;
        if ($this->hasReference($fixtureRef, Route::class)) {
            $route = $this->getReference($fixtureRef, Route::class);
        } else {
            $route = new Route();
            $this->getTimestampedDataPersister()->persistTimestampedFields($route, true);
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

    public static function getSubscribedServices(): array
    {
        return [
            TimestampedDataPersister::class,
            IriConverterInterface::class,
            CwaPlaceholderProvider::class
        ];
    }
}
