<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20210908104723 extends AbstractMigration
{
    public function getDescription(): string
    {
        return '';
    }

    public function up(Schema $schema): void
    {
        // this up() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE _acb_page DROP CONSTRAINT FK_27CCF323AB211837');
        $this->addSql('ALTER TABLE _acb_page DROP CONSTRAINT FK_27CCF32334ECB4E6');
        $this->addSql('ALTER TABLE _acb_page ADD CONSTRAINT FK_27CCF323AB211837 FOREIGN KEY (parent_route_id) REFERENCES _acb_route (id) ON DELETE SET NULL NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_page ADD CONSTRAINT FK_27CCF32334ECB4E6 FOREIGN KEY (route_id) REFERENCES _acb_route (id) ON DELETE SET NULL NOT DEFERRABLE INITIALLY IMMEDIATE');
    }

    public function down(Schema $schema): void
    {
        // this down() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE _acb_page DROP CONSTRAINT fk_27ccf323ab211837');
        $this->addSql('ALTER TABLE _acb_page DROP CONSTRAINT fk_27ccf32334ecb4e6');
        $this->addSql('ALTER TABLE _acb_page ADD CONSTRAINT fk_27ccf323ab211837 FOREIGN KEY (parent_route_id) REFERENCES _acb_route (id) NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_page ADD CONSTRAINT fk_27ccf32334ecb4e6 FOREIGN KEY (route_id) REFERENCES _acb_route (id) NOT DEFERRABLE INITIALLY IMMEDIATE');
    }
}
