<?php

namespace App\DataFixtures;

use App\Entity\Button;
use App\Entity\HtmlContent;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;

class HomePageFixture extends AbstractPageFixture
{
    public function load(ObjectManager $manager): void
    {
        $layout = $this->createLayout('primary', 'PrimaryLayout');
        $manager->persist($layout);
        $this->addHomePage($manager, $layout);

        $manager->flush();
    }

    private function addHomePage(ObjectManager $manager, Layout $layout): void
    {
        $page = $this->createPage('home', 'PrimaryPageTemplate', $layout);
        $page->setTitle('Welcome to CWA')->setMetaDescription('A demo CWA website');
        $manager->persist($page);

        $htmlContent = new HtmlContent();
        $htmlContent->html = '<p>Bonjour mon ami</p>';
        $htmlContent->setPublishedAt(new \DateTime());
        $manager->persist($htmlContent);

        $componentCollection = $this->createComponentCollection($page, 'primary');
        $manager->persist($componentCollection);

        $position = $this->createComponentPosition($componentCollection, $htmlContent, 0);
        $manager->persist($position);

        $route = $this->createRoute('/', 'home-page', $page);
        $manager->persist($route);
    }
}
