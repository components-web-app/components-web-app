<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20261125110101 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Component group allowed UI variants (bundle 2.0.0-alpha.46, api-components-bundle#613)';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE _acb_component_group ADD allowed_component_ui JSON DEFAULT NULL');
    }
}
