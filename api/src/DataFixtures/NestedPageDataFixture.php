<?php

declare(strict_types=1);

namespace App\DataFixtures;

use App\Entity\HtmlContent;
use App\Entity\NestedPageData;
use App\Entity\NestedSubPageData;
use Doctrine\Common\DataFixtures\DependentFixtureInterface;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;
use Silverback\ApiComponentsBundle\Entity\Core\Page;
use Silverback\ApiComponentsBundle\Helper\Route\RouteGeneratorInterface;

/**
 * Demonstrates nested page data: NestedPageData instances each contain child NestedSubPageData pages.
 * Child routes are automatically built as /{parent-slug}/{child-slug} by the route generator.
 */
class NestedPageDataFixture extends AbstractPageFixture implements DependentFixtureInterface
{
    public static function getSubscribedServices(): array
    {
        return array_merge(parent::getSubscribedServices(), [
            RouteGeneratorInterface::class,
        ]);
    }

    public function load(ObjectManager $manager): void
    {
        $layout = $this->createLayout($manager, 'Main Layout', 'CwaLayoutPrimary');
        [$parentTemplatePage, $childTemplatePage] = $this->createTemplatePages($manager, $layout);

        $parents = $this->createParentPages($manager, $parentTemplatePage);

        $manager->flush();

        $this->createChildPages($manager, $childTemplatePage, $parents);
    }

    private function createTemplatePages(ObjectManager $manager, Layout $layout): array
    {
        $parentTemplatePage = $this->createPage('nested-topic-template', 'PrimaryPageTemplate', $layout, true);
        $manager->persist($parentTemplatePage);

        $parentGroup = $this->createComponentGroup('primary', $parentTemplatePage);
        $manager->persist($parentGroup);

        $introPosition = $this->createComponentPosition($parentGroup, null, 0);
        $introPosition->setPageDataProperty('introContent');
        $manager->persist($introPosition);

        $childTemplatePage = $this->createPage('nested-sub-page-template', 'PrimaryPageTemplate', $layout, true);
        $manager->persist($childTemplatePage);

        $childGroup = $this->createComponentGroup('primary', $childTemplatePage);
        $manager->persist($childGroup);

        $bodyPosition = $this->createComponentPosition($childGroup, null, 0);
        $bodyPosition->setPageDataProperty('bodyContent');
        $manager->persist($bodyPosition);

        $manager->flush();

        return [$parentTemplatePage, $childTemplatePage];
    }

    /**
     * @return NestedPageData[]
     */
    private function createParentPages(ObjectManager $manager, Page $templatePage): array
    {
        $parents = [];

        for ($i = 1; $i <= 2; $i++) {
            $intro = new HtmlContent();
            $intro->html = sprintf('<p>Introduction to topic %d. This page has nested sub-pages beneath it.</p>', $i);
            $intro->setPublishedAt(new \DateTime());
            $manager->persist($intro);

            $pageData = new NestedPageData();
            $pageData->setTitle(sprintf('Topic %d', $i));
            $pageData->setMetaDescription(sprintf('A nested topic page with sub-pages beneath it (%d)', $i));
            $pageData->introContent = $intro;
            $pageData->page = $templatePage;
            $this->getTimestampedDataPersister()->persistTimestampedFields($pageData, true);
            $manager->persist($pageData);

            $route = $this->container->get(RouteGeneratorInterface::class)->create($pageData);
            $manager->persist($route);

            $parents[] = $pageData;
        }

        return $parents;
    }

    /**
     * @param NestedPageData[] $parents
     */
    private function createChildPages(ObjectManager $manager, Page $templatePage, array $parents): void
    {
        foreach ($parents as $parentIndex => $parent) {
            for ($j = 1; $j <= 2; $j++) {
                $body = new HtmlContent();
                $body->html = sprintf('<p>Content for sub-page %d under topic %d.</p>', $j, $parentIndex + 1);
                $body->setPublishedAt(new \DateTime());
                $manager->persist($body);

                $subPageData = new NestedSubPageData();
                $subPageData->setTitle(sprintf('Sub Page %d', $j));
                $subPageData->setMetaDescription(sprintf('Sub page %d under topic %d', $j, $parentIndex + 1));
                $subPageData->bodyContent = $body;
                $subPageData->page = $templatePage;
                $subPageData->setParentPageData($parent);
                $this->getTimestampedDataPersister()->persistTimestampedFields($subPageData, true);
                $manager->persist($subPageData);

                $route = $this->container->get(RouteGeneratorInterface::class)->create($subPageData);
                $manager->persist($route);
            }

            $manager->flush();
        }
    }

    public function getDependencies(): array
    {
        return [
            HomePageFixture::class,
        ];
    }
}
