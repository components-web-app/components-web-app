<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20261127221141 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'User admin preferences (bundle 2.0.0-alpha.49, api-components-bundle#620)';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE "user" ADD admin_preferences JSON DEFAULT NULL');
    }
}
