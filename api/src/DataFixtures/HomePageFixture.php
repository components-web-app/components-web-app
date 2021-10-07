<?php

namespace App\DataFixtures;

use App\Entity\HtmlContent;
use App\Entity\Image;
use DateTime;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;

class HomePageFixture extends AbstractPageFixture
{
    public function load(ObjectManager $manager): void
    {
        $layout = $this->createLayout($manager, 'Main Layout', 'primary');
        $this->addHomePage($manager, $layout);

        $manager->flush();
    }

    private function addHomePage(ObjectManager $manager, Layout $layout): void
    {
        $page = $this->createPage('home', 'PrimaryPageTemplate', $layout);
        $page->setTitle('Welcome to CWA')->setMetaDescription('A demo CWA website');
        $manager->persist($page);

        $componentCollection = $this->createComponentCollection( 'primary', $page);
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

        $image = new Image();
        $manager->persist($image);
        $position = $this->createComponentPosition($componentCollection, $image, 1);
        $manager->persist($position);

        $htmlContent = new HtmlContent();
        $htmlContent->html = $this->lipsumContentProvider->generate([
            '1',
            'medium',
            'link',
        ]);
        $htmlContent->setPublishedAt(new DateTime());
        $manager->persist($htmlContent);
        $position = $this->createComponentPosition($componentCollection, $htmlContent, 2);
        $manager->persist($position);

        $componentCollection2 = $this->createComponentCollection( 'secondary', $page);
        $manager->persist($componentCollection2);

        $htmlContent2 = new HtmlContent();
        $htmlContent2->html = $this->lipsumContentProvider->generate([
            '2',
            'short'
        ]);
        $htmlContent2->setPublishedAt(new DateTime());
        $manager->persist($htmlContent2);
        $position2 = $this->createComponentPosition($componentCollection2, $htmlContent2, 0);
        $manager->persist($position2);

        $this->addReference('side_html', $htmlContent2);

        $route = $this->createRoute('/', 'home-page', $page);
        $manager->persist($route);
    }
}
