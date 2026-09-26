<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20260926075921 extends AbstractMigration
{
    public function getDescription(): string
    {
        return '';
    }

    public function up(Schema $schema): void
    {
        // this up() migration is auto-generated, please modify it to your needs
        $this->addSql(<<<'SQL'
            CREATE TABLE _acb_orphaned_resource_report (
              id SMALLINT NOT NULL,
              generated_at VARCHAR(32) NOT NULL,
              component_groups JSON NOT NULL,
              component_positions JSON NOT NULL,
              components JSON NOT NULL,
              last_notified JSON DEFAULT NULL,
              PRIMARY KEY (id)
            )
        SQL);
    }

    public function down(Schema $schema): void
    {
        // this down() migration is auto-generated, please modify it to your needs
        $this->addSql('DROP TABLE _acb_orphaned_resource_report');
    }
}
