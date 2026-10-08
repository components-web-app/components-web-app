<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20261008121224 extends AbstractMigration
{
    public function getDescription(): string
    {
        return '';
    }

    public function up(Schema $schema): void
    {
        // this up() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE _acb_abstract_page_data ADD is_reachable_without_route BOOLEAN DEFAULT false NOT NULL');
        $this->addSql('ALTER TABLE _acb_page ADD is_reachable_without_route BOOLEAN DEFAULT false NOT NULL');
    }
}
