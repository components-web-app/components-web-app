<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20210927105125 extends AbstractMigration
{
    public function getDescription(): string
    {
        return '';
    }

    public function up(Schema $schema): void
    {
        // this up() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE _acb_abstract_component ADD image_id UUID DEFAULT NULL');
        $this->addSql('ALTER TABLE _acb_abstract_component ADD filename VARCHAR(255) DEFAULT NULL');
        $this->addSql('ALTER TABLE _acb_abstract_component ADD CONSTRAINT FK_4EBC1A193DA5256D FOREIGN KEY (image_id) REFERENCES _acb_abstract_component (id) ON DELETE SET NULL NOT DEFERRABLE INITIALLY IMMEDIATE');
    }

    public function down(Schema $schema): void
    {
        // this down() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE _acb_abstract_component DROP CONSTRAINT FK_4EBC1A193DA5256D');
        $this->addSql('ALTER TABLE _acb_abstract_component DROP image_id');
        $this->addSql('ALTER TABLE _acb_abstract_component DROP filename');
    }
}
