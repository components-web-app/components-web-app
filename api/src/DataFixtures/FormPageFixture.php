<?php

namespace App\DataFixtures;

use App\Form\ExampleFormType;
use Doctrine\Common\DataFixtures\DependentFixtureInterface;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Component\Form;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;

class FormPageFixture extends AbstractPageFixture implements DependentFixtureInterface
{
    public function load(ObjectManager $manager): void
    {
        $layout = $this->createLayout($manager, 'Main Layout', 'primary');
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
        $manager->persist($form);

        $componentCollection = $this->createComponentCollection('primary', $page);
        $manager->persist($componentCollection);

        $position = $this->createComponentPosition($componentCollection, $form, 0);
        $manager->persist($position);

        $componentCollection2 = $this->createComponentCollection( 'secondary', $page);
        $manager->persist($componentCollection2);
        $position2 = $this->createComponentPosition($componentCollection2, $this->getReference('side_html'), 0);
        $manager->persist($position2);

        $route = $this->createRoute('/form', 'form-page', $page);
        $manager->persist($route);
    }

    public function getDependencies(): array
    {
        return [
            HomePageFixture::class
        ];
    }
}
