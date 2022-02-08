<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20220203123117 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add navigation link component';
    }

    public function up(Schema $schema): void
    {
        // this up() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE _acb_abstract_component ADD route_id UUID DEFAULT NULL');
        $this->addSql('ALTER TABLE _acb_abstract_component ADD navigation_link_id UUID DEFAULT NULL');
        $this->addSql('ALTER TABLE _acb_abstract_component ADD label TEXT DEFAULT NULL');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_component.route_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_component.navigation_link_id IS \'(DC2Type:uuid)\'');
        $this->addSql('ALTER TABLE _acb_abstract_component ADD CONSTRAINT FK_4EBC1A1934ECB4E6 FOREIGN KEY (route_id) REFERENCES _acb_route (id) NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_abstract_component ADD CONSTRAINT FK_4EBC1A19EB260C02 FOREIGN KEY (navigation_link_id) REFERENCES _acb_abstract_component (id) ON DELETE SET NULL NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('CREATE INDEX IDX_4EBC1A1934ECB4E6 ON _acb_abstract_component (route_id)');
        $this->addSql('CREATE INDEX IDX_4EBC1A19EB260C02 ON _acb_abstract_component (navigation_link_id)');
    }

    public function down(Schema $schema): void
    {
        // this down() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE _acb_abstract_component DROP CONSTRAINT FK_4EBC1A1934ECB4E6');
        $this->addSql('ALTER TABLE _acb_abstract_component DROP CONSTRAINT FK_4EBC1A19EB260C02');
        $this->addSql('DROP INDEX IDX_4EBC1A1934ECB4E6');
        $this->addSql('DROP INDEX IDX_4EBC1A19EB260C02');
        $this->addSql('ALTER TABLE _acb_abstract_component DROP route_id');
        $this->addSql('ALTER TABLE _acb_abstract_component DROP navigation_link_id');
        $this->addSql('ALTER TABLE _acb_abstract_component DROP label');
    }
}
