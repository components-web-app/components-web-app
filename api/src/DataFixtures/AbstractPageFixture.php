<?php

declare(strict_types=1);


namespace App\DataFixtures;


use App\Entity\HtmlContent;
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

    public function __construct(TimestampedDataPersister $timestampedDataPersister, LipsumContentProvider $lipsumContentProvider)
    {
        $this->timestampedDataPersister = $timestampedDataPersister;
        $this->lipsumContentProvider = $lipsumContentProvider;
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

        $htmlContent = new HtmlContent();
        $htmlContent->html = '<h1>Welcome to CWA</h1><p><a href="/">Home</a> | <a href="/blog-articles">Blog</a> | <a href="/form">Form</a></p>';
        $htmlContent->uiClassNames = ['is-feature'];
        $htmlContent->setPublishedAt(new \DateTime());

        $position = $this->createComponentPosition($componentCollectionTop, $htmlContent, 0);

        $return = [ $layout, $componentCollectionTop, $htmlContent, $position];
        foreach ($return as $item) {
            $manager->persist($item);
        }
        $this->addReference($fixtureRef, $layout);
        return $layout;
    }

    protected function persistArray(ObjectManager $manager, $array)
    {
        foreach ($array as $item) {
            $manager->persist($item);
        }
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
