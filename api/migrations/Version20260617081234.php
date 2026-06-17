<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20260617081234 extends AbstractMigration
{
    public function getDescription(): string
    {
        return '';
    }

    public function up(Schema $schema): void
    {
        // this up() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE _acb_abstract_page_data DROP CONSTRAINT fk_2d7554f7c4663e4');
        $this->addSql('ALTER TABLE _acb_abstract_page_data ADD CONSTRAINT FK_2D7554F7C4663E4 FOREIGN KEY (page_id) REFERENCES _acb_page (id) ON DELETE CASCADE NOT DEFERRABLE');
    }

    public function down(Schema $schema): void
    {
        // this down() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE _acb_abstract_page_data DROP CONSTRAINT FK_2D7554F7C4663E4');
        $this->addSql('ALTER TABLE _acb_abstract_page_data ADD CONSTRAINT fk_2d7554f7c4663e4 FOREIGN KEY (page_id) REFERENCES _acb_page (id) NOT DEFERRABLE INITIALLY IMMEDIATE');
    }
}
