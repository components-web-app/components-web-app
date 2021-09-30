<?php

namespace App\DataFixtures;

use App\Entity\HtmlContent;
use DateTime;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;

class HomePageFixture extends AbstractPageFixture
{
    public function load(ObjectManager $manager): void
    {
        $layout = $this->createLayout('Main Layout', 'primary');
        $manager->persist($layout);
        $this->addHomePage($manager, $layout);

        $manager->flush();
    }

    private function addHomePage(ObjectManager $manager, Layout $layout): void
    {
        $page = $this->createPage('home', 'PrimaryPageTemplate', $layout);
        $page->setTitle('Welcome to CWA')->setMetaDescription('A demo CWA website');
        $manager->persist($page);

        $componentCollection = $this->createComponentCollection($page, 'primary');
        $manager->persist($componentCollection);

        $htmlContent = new HtmlContent();
        $htmlContent->html = $this->lipsumContentProvider->generate([
            '2',
            'short',
            'headers',
            'link',
        ]);
        $htmlContent->setPublishedAt(new DateTime());
        $manager->persist($htmlContent);
        $position = $this->createComponentPosition($componentCollection, $htmlContent, 0);
        $manager->persist($position);

        $htmlContent = new HtmlContent();
        $htmlContent->html = $this->lipsumContentProvider->generate([
            '1',
            'medium',
            'link',
        ]);
        $htmlContent->setPublishedAt(new DateTime());
        $manager->persist($htmlContent);
        $position = $this->createComponentPosition($componentCollection, $htmlContent, 1);
        $manager->persist($position);

        $route = $this->createRoute('/', 'home-page', $page);
        $manager->persist($route);
    }
}
