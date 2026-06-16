<?php

declare(strict_types=1);

namespace App\DataFixtures;

use App\Entity\HtmlContent;
use App\Entity\NestedPageData;
use Doctrine\Common\DataFixtures\DependentFixtureInterface;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;
use Silverback\ApiComponentsBundle\Entity\Core\Page;
use Silverback\ApiComponentsBundle\Helper\Route\RouteGeneratorInterface;

/**
 * Demonstrates CWA nested pages using static Page entities as children of NestedPageData instances.
 * Setting parentPageData on a Page causes RouteGenerator to prefix its path with the parent route,
 * and the module manifest groups them by depth so NestedTopicTemplate renders at depth 0 while the
 * child Page's uiComponent renders at depth 1 via <CwaPage />.
 */
class NestedPageDataFixture extends AbstractPageFixture implements DependentFixtureInterface
{
    // Child pages use unique titles so RouteGenerator produces clean, predictable route paths.
    private const TOPIC_CHILDREN = [
        1 => [
            ['title' => 'Chapter One',   'path' => '/topic-1/chapter-one'],
            ['title' => 'Chapter Two',   'path' => '/topic-1/chapter-two'],
        ],
        2 => [
            ['title' => 'Chapter Three', 'path' => '/topic-2/chapter-three'],
            ['title' => 'Chapter Four',  'path' => '/topic-2/chapter-four'],
        ],
    ];

    public static function getSubscribedServices(): array
    {
        return array_merge(parent::getSubscribedServices(), [
            RouteGeneratorInterface::class,
        ]);
    }

    public function load(ObjectManager $manager): void
    {
        $layout = $this->createLayout($manager, 'Main Layout', 'CwaLayoutPrimary');
        $templatePage = $this->createTopicTemplatePage($manager, $layout);

        $parents = $this->createTopics($manager, $templatePage);

        $layoutTopGroup = $this->createComponentGroup('top', null, $layout);
        $sort = 3;
        foreach ($parents as $topicNum => $parent) {
            $this->addNavigationLink($manager, $layoutTopGroup, sprintf('Topic %d', $topicNum), null, null, $sort++, $parent->getRoute());
        }

        $this->createChildPages($manager, $layout, $parents);
    }

    private function createTopicTemplatePage(ObjectManager $manager, Layout $layout): Page
    {
        $templatePage = $this->createPage('nested-topic-template', 'NestedTopicTemplate', $layout, true);
        $manager->persist($templatePage);

        // Empty fallback group — used when pageDataIri is unavailable (e.g., direct admin access to the template page)
        $group = $this->createComponentGroup('primary', $templatePage);
        $manager->persist($group);

        $manager->flush();

        return $templatePage;
    }

    /** @return array<int, NestedPageData> keyed by topic number */
    private function createTopics(ObjectManager $manager, Page $templatePage): array
    {
        $parents = [];

        foreach (self::TOPIC_CHILDREN as $topicNum => $children) {
            $childLinks = implode(' | ', array_map(
                fn(array $c) => sprintf('<a href="%s">%s</a>', $c['path'], $c['title']),
                $children
            ));

            $pageData = new NestedPageData();
            $pageData->setTitle(sprintf('Topic %d', $topicNum));
            $pageData->setMetaDescription(sprintf('Nested topic %d demonstrating static child pages', $topicNum));
            $pageData->page = $templatePage;
            $this->getTimestampedDataPersister()->persistTimestampedFields($pageData, true);
            $manager->persist($pageData);

            $route = $this->container->get(RouteGeneratorInterface::class)->create($pageData);
            $manager->persist($route);
            $manager->flush(); // UUID must be assigned before we can compute the pageData IRI

            // Per-instance component group: reference and location keyed to the pageData IRI so the
            // module's CwaComponentGroup (location=pageDataIri) can find it. Associating with
            // $templatePage means it is returned in the template page's componentGroups response
            // and is therefore fetched for unauthenticated users via the page chain.
            $group = $this->createComponentGroup('primary', $templatePage, null, $pageData);
            $manager->persist($group);

            $intro = new HtmlContent();
            $intro->html = sprintf(
                '<p>Introduction to Topic %d.</p><p>Child pages: %s</p>'
                . '<p>Navigate to a child URL to see nested rendering — the topic intro above '
                . 'remains visible while the child page content appears below via <code>&lt;CwaPage /&gt;</code>.</p>',
                $topicNum,
                $childLinks
            );
            $intro->setPublishedAt(new \DateTime());
            $manager->persist($intro);

            $position = $this->createComponentPosition($group, $intro, 0);
            $manager->persist($position);
            $manager->flush();

            $parents[$topicNum] = $pageData;
        }

        return $parents;
    }

    /**
     * Creates static Page entities as children of each NestedPageData.
     *
     * @param array<int, NestedPageData> $parents keyed by topic number
     */
    private function createChildPages(ObjectManager $manager, Layout $layout, array $parents): void
    {
        foreach (self::TOPIC_CHILDREN as $topicNum => $children) {
            $parent = $parents[$topicNum];

            foreach ($children as $j => $child) {
                $htmlContent = new HtmlContent();
                $htmlContent->html = sprintf(
                    '<p><strong>%s</strong> — a static child <code>Page</code> of Topic %d\'s <code>NestedPageData</code>. '
                    . 'The topic template is rendered at depth 0; this page renders at depth 1 via <code>&lt;CwaPage /&gt;</code>.</p>',
                    $child['title'],
                    $topicNum
                );
                $htmlContent->setPublishedAt(new \DateTime());
                $manager->persist($htmlContent);

                $childPage = $this->createPage(
                    sprintf('topic-%d-chapter-%d', $topicNum, $j + 1),
                    'NestedSubPageTemplate',
                    $layout,
                    false
                );
                $childPage->setTitle($child['title']);
                $childPage->setParentPageData($parent);
                $manager->persist($childPage);

                $childGroup = $this->createComponentGroup('primary', $childPage);
                $manager->persist($childGroup);

                $position = $this->createComponentPosition($childGroup, $htmlContent, 0);
                $manager->persist($position);

                $route = $this->container->get(RouteGeneratorInterface::class)->create($childPage);
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
