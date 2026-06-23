<?php

declare(strict_types=1);

namespace App\DataFixtures\Parts;

use App\Form\ExampleFormType;
use Silverback\ApiComponentsBundle\Entity\Component\Form;
use Silverback\ApiComponentsBundle\Fixture\Builder\PageBuilder;
use Silverback\ApiComponentsBundle\Fixture\CwaFixtureBuilder;

class FormsScaffoldPart implements ScaffoldPartInterface
{
    public static function getPriority(): int
    {
        return 30;
    }

    public function build(CwaFixtureBuilder $cwa, ScaffoldState $state): void
    {
        $formComponent = new Form();
        $formComponent->formType = ExampleFormType::class;
        $formComponent->uiComponent = 'ExampleForm';
        // Workaround: CwaFixtureBuilder::createPositions() does not call persistTimestampedFields
        // on components added via GroupBuilder::add() — only on their ComponentPosition.
        $formComponent->createdAt = new \DateTimeImmutable();
        $formComponent->modifiedAt = new \DateTime();

        $cwa->page('form', 'PrimaryPageTemplate', layout: 'main', route: '/form', routeName: 'form-page',
            configure: function (PageBuilder $p) use ($formComponent) {
                $p->title('Form Demo')->metaDescription('A demo form showing all Symfony form field types with CWA form composables');
                $p->group('primary')->add($formComponent);
            }
        );
    }
}
