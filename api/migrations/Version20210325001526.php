<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20210325001526 extends AbstractMigration
{
    public function getDescription() : string
    {
        return 'add version field to refresh token table';
    }

    public function up(Schema $schema) : void
    {
        $this->addSql('ALTER TABLE refresh_token ADD version INT DEFAULT 1 NOT NULL');
    }

    public function down(Schema $schema) : void
    {
        $this->addSql('ALTER TABLE refresh_token DROP version');
    }
}
