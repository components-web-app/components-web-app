<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20261016233432 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Bundle 2.0.0-alpha.23: component group max_components';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE _acb_component_group ADD max_components INT DEFAULT NULL');
    }
}
