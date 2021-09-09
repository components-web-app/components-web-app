<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20210907161725 extends AbstractMigration
{
    public function getDescription(): string
    {
        return '';
    }

    public function up(Schema $schema): void
    {
        // this up() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE _acb_abstract_page_data DROP CONSTRAINT FK_2D7554F734ECB4E6');
        $this->addSql('ALTER TABLE _acb_abstract_page_data ADD CONSTRAINT FK_2D7554F734ECB4E6 FOREIGN KEY (route_id) REFERENCES _acb_route (id) ON DELETE SET NULL NOT DEFERRABLE INITIALLY IMMEDIATE');
    }

    public function down(Schema $schema): void
    {
        // this down() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE _acb_abstract_page_data DROP CONSTRAINT fk_2d7554f734ecb4e6');
        $this->addSql('ALTER TABLE _acb_abstract_page_data ADD CONSTRAINT fk_2d7554f734ecb4e6 FOREIGN KEY (route_id) REFERENCES _acb_route (id) NOT DEFERRABLE INITIALLY IMMEDIATE');
    }
}
