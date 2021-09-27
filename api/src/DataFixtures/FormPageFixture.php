<?php

namespace App\DataFixtures;

use App\Form\ExampleFormType;
use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Component\Form;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;
use Silverback\ApiComponentsBundle\Form\Type\User\UserRegisterType;

class FormPageFixture extends AbstractPageFixture
{
    public function load(ObjectManager $manager): void
    {
        $layout = $this->createLayout('Main Layout', 'primary');
        $manager->persist($layout);
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

        $componentCollection = $this->createComponentCollection($page, 'primary');
        $manager->persist($componentCollection);

        $position = $this->createComponentPosition($componentCollection, $form, 0);
        $manager->persist($position);

        $route = $this->createRoute('/form', 'form-page', $page);
        $manager->persist($route);
    }
}
