<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20261010125853 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Bundle 2.0.0-alpha.11: invalid files in the orphaned file report';
    }

    public function up(Schema $schema): void
    {
        // Existing report rows get an empty list; the default is then dropped to match the mapping.
        $this->addSql("ALTER TABLE _acb_orphaned_file_report ADD invalid_files JSON DEFAULT '[]' NOT NULL");
        $this->addSql('ALTER TABLE _acb_orphaned_file_report ALTER invalid_files DROP DEFAULT');
    }
}
