<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20261013020000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Bundle 2.0.0-alpha.18: store page uiComponent as the full CwaPage name';
    }

    public function up(Schema $schema): void
    {
        // The bundle's alpha.18 upgrade step, as prefix-page-ui-components does it (api-components-bundle#431).
        $this->addSql("UPDATE _acb_page SET ui_component = 'CwaPage' || ui_component WHERE ui_component <> '' AND ui_component NOT LIKE 'CwaPage%'");
    }
}
