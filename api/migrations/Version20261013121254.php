<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20261013121254 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Bundle 2.0.0-alpha.19: page and page data titles default to null';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE _acb_abstract_page_data ALTER title DROP NOT NULL');
        // The bundle's alpha.19 upgrade step: clear the old default title (api-components-bundle#440).
        $this->addSql("UPDATE _acb_page SET title = NULL WHERE title = 'Unnamed Page'");
        $this->addSql("UPDATE _acb_abstract_page_data SET title = NULL WHERE title = 'Unnamed Page'");
    }
}
