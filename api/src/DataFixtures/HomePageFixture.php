<?php

namespace App\DataFixtures;

use App\Entity\HtmlContent;
use App\Entity\Image;
use DateTime;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;

class HomePageFixture extends AbstractPageFixture
{
    public const ROUTE_NAME = 'home-page';

    public function load(ObjectManager $manager): void
    {
        $layout = $this->createLayout($manager, 'Main Layout', 'CwaLayoutPrimary');
        $this->addHomePage($manager, $layout);

        $manager->flush();
    }

    private function addHtmlContent(array $ops, bool $published = true) {
        $htmlContent = new HtmlContent();
        $htmlContent->html = $this->lipsumContentProvider->generate($ops);
        $htmlContent->setPublishedAt($published ? new DateTime() : null);
        return $htmlContent;
    }

    private function addHomePage(ObjectManager $manager, Layout $layout): void
    {
        $page = $this->createPage('home', 'PrimaryPageTemplate', $layout);
        $page->setTitle('Welcome to CWA')->setMetaDescription('A demo CWA website');
        $manager->persist($page);

        $componentGroup = $this->createComponentGroup( 'primary', $page);
        $manager->persist($componentGroup);

        $htmlContent = $this->addHtmlContent([
            '2',
            'short',
            'headers',
            'link',
        ]);
        $manager->persist($htmlContent);
        $position = $this->createComponentPosition($componentGroup, $htmlContent, 0);
        $manager->persist($position);

        $htmlContentDraft = $this->addHtmlContent([
            '1',
            'medium'
        ], false);
        $htmlContentDraft->setPublishedResource($htmlContent);
        $manager->persist($htmlContentDraft);

        $image = new Image();
        $manager->persist($image);
        $position = $this->createComponentPosition($componentGroup, $image, 1);
        $manager->persist($position);

        $htmlContentBottom = $this->addHtmlContent([
            '1',
            'medium',
            'link'
        ]);
        $manager->persist($htmlContentBottom);
        $position = $this->createComponentPosition($componentGroup, $htmlContentBottom, 2);
        $manager->persist($position);

        $route = $this->createRoute('/', self::ROUTE_NAME, $page);
        $manager->persist($route);
    }
}
