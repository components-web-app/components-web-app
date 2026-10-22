<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20261022184324 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Bundle 2.0.0-alpha.36: resource_version on components and page data (ETag, If-Match)';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE _acb_abstract_component ADD resource_version INT DEFAULT 1 NOT NULL');
        $this->addSql('ALTER TABLE _acb_abstract_page_data ADD resource_version INT DEFAULT 1 NOT NULL');
    }
}
