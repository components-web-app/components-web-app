<?php

namespace App\DataFixtures;

use App\Entity\HtmlContent;
use Doctrine\Bundle\FixturesBundle\Fixture;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractComponent;
use Silverback\ApiComponentsBundle\Entity\Core\ComponentCollection;
use Silverback\ApiComponentsBundle\Entity\Core\ComponentPosition;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;
use Silverback\ApiComponentsBundle\Entity\Core\Page;
use Silverback\ApiComponentsBundle\Entity\Core\Route;
use Silverback\ApiComponentsBundle\Helper\Timestamped\TimestampedDataPersister;

class HomePageFixture extends Fixture
{
    private TimestampedDataPersister $timestampedDataPersister;

    public function __construct(TimestampedDataPersister $timestampedDataPersister)
    {
        $this->timestampedDataPersister = $timestampedDataPersister;
    }

    public function load(ObjectManager $manager): void
    {
        $layout = new Layout();
        $layout->reference = 'primary';
        $this->timestampedDataPersister->persistTimestampedFields($layout, true);
        $manager->persist($layout);
        $this->addHomePage($manager, $layout);

        $manager->flush();
    }

    private function addHomePage(ObjectManager $manager, Layout $layout): void
    {
        $page = $this->createPage('home', $layout);
        $manager->persist($page);

        $componentCollection = $this->createComponentCollection($page, 'primary');
        $manager->persist($componentCollection);

        $htmlContent = new HtmlContent();
        $htmlContent->html = '<p>Bonjour mon ami</p>';
        $manager->persist($htmlContent);

        $position = $this->createComponentPosition($componentCollection, $htmlContent, 0);
        $manager->persist($position);

        $route = new Route();
        $route
            ->setPath('/home')
            ->setName('home')
            ->setPage($page)
        ;
        $this->timestampedDataPersister->persistTimestampedFields($route, true);
        $manager->persist($route);
    }

    private function createPage(string $reference, Layout $layout): Page
    {
        $page = new Page();
        $page->reference = $reference;
        $page->layout = $layout;
        $this->timestampedDataPersister->persistTimestampedFields($page, true);
        return $page;
    }

    private function createComponentCollection(Page $page, string $reference): ComponentCollection
    {
        $componentCollection = new ComponentCollection();
        $componentCollection->setReference($reference)->addPage($page);
        $this->timestampedDataPersister->persistTimestampedFields($componentCollection, true);
        return $componentCollection;
    }

    private function createComponentPosition(ComponentCollection $componentCollection, AbstractComponent $component, ?int $sortValue = null): ComponentPosition
    {
        $position = new ComponentPosition();
        $position
            ->setComponent($component)
            ->setComponentCollection($componentCollection)
            ->setSortValue($sortValue);
        $this->timestampedDataPersister->persistTimestampedFields($position, true);
        return $position;
    }
}
