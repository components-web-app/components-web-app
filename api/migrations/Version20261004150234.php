<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20261004150234 extends AbstractMigration
{
    public function getDescription(): string
    {
        return '';
    }

    public function up(Schema $schema): void
    {
        // this up() migration is auto-generated, please modify it to your needs
        $this->addSql('CREATE TABLE _acb_orphaned_file_report (id SMALLINT NOT NULL, generated_at VARCHAR(32) NOT NULL, orphaned_files JSON NOT NULL, missing_files JSON NOT NULL, unknown_files JSON NOT NULL, PRIMARY KEY (id))');
    }
}
