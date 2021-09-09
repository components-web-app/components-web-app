<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20210908105111 extends AbstractMigration
{
    public function getDescription(): string
    {
        return '';
    }

    public function up(Schema $schema): void
    {
        // this up() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE _acb_route DROP CONSTRAINT FK_9BFEB786C30C9E2B');
        $this->addSql('ALTER TABLE _acb_route ADD CONSTRAINT FK_9BFEB786C30C9E2B FOREIGN KEY (redirect) REFERENCES _acb_route (id) ON DELETE CASCADE NOT DEFERRABLE INITIALLY IMMEDIATE');
    }

    public function down(Schema $schema): void
    {
        // this down() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE _acb_route DROP CONSTRAINT fk_9bfeb786c30c9e2b');
        $this->addSql('ALTER TABLE _acb_route ADD CONSTRAINT fk_9bfeb786c30c9e2b FOREIGN KEY (redirect) REFERENCES _acb_route (id) ON DELETE SET NULL NOT DEFERRABLE INITIALLY IMMEDIATE');
    }
}
