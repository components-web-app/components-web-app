<?php

namespace App\DataFixtures;

use App\Form\ExampleFormType;
use Doctrine\Common\DataFixtures\DependentFixtureInterface;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Component\Form;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;

class FormPageFixture extends AbstractPageFixture implements DependentFixtureInterface
{
    public const ROUTE_NAME = 'form-page';

    public function load(ObjectManager $manager): void
    {
        $layout = $this->createLayout($manager, 'Main Layout', 'CwaLayoutPrimary');
        $this->addRegisterPage($manager, $layout);

        $manager->flush();
    }

    private function addRegisterPage(ObjectManager $manager, Layout $layout): void
    {
        $page = $this->createPage('form', 'PrimaryPageTemplate', $layout);
        $page->setTitle('Form')->setMetaDescription('A sample CWA register page using a form');
        $manager->persist($page);

        $form = new Form();
        $form->formType = ExampleFormType::class;
        $this->timestampedDataPersister->persistTimestampedFields($form, true);
        $manager->persist($form);

        $componentGroup = $this->createComponentGroup('primary', $page);
        $manager->persist($componentGroup);

        $position = $this->createComponentPosition($componentGroup, $form, 0);
        $manager->persist($position);

        $route = $this->createRoute('/form', self::ROUTE_NAME, $page);
        $manager->persist($route);
    }

    public function getDependencies(): array
    {
        return [
            HomePageFixture::class
        ];
    }
}
