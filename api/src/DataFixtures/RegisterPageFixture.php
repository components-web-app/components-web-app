<?php

namespace App\DataFixtures;

use Doctrine\Persistence\ObjectManager;
use Silverback\ApiComponentsBundle\Entity\Component\Form;
use Silverback\ApiComponentsBundle\Entity\Core\Layout;
use Silverback\ApiComponentsBundle\Form\Type\User\UserRegisterType;

class RegisterPageFixture extends AbstractPageFixture
{
    public function load(ObjectManager $manager): void
    {
        $layout = $this->createLayout('primary', 'PrimaryLayout');
        $manager->persist($layout);
        $this->addRegisterPage($manager, $layout);

        $manager->flush();
    }

    private function addRegisterPage(ObjectManager $manager, Layout $layout): void
    {
        $page = $this->createPage('register', 'PrimaryPageTemplate', $layout);
        $manager->persist($page);

        $form = new Form();
        $form->formType = UserRegisterType::class;
        $manager->persist($form);

        $componentCollection = $this->createComponentCollection($page, 'primary');
        $manager->persist($componentCollection);

        $position = $this->createComponentPosition($componentCollection, $form, 0);
        $manager->persist($position);

        $route = $this->createRoute('/register', 'register-page', $page);
        $manager->persist($route);
    }
}
