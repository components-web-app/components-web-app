<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20240916120036 extends AbstractMigration
{
    public function getDescription(): string
    {
        return '';
    }

    public function up(Schema $schema): void
    {
        // this up() migration is auto-generated, please modify it to your needs
        $this->addSql('CREATE TABLE title (id UUID NOT NULL, title_id UUID DEFAULT NULL, title TEXT DEFAULT NULL, published_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NULL, PRIMARY KEY(id))');
        $this->addSql('CREATE UNIQUE INDEX UNIQ_2B36786BA9F87BD ON title (title_id)');
        $this->addSql('COMMENT ON COLUMN title.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN title.title_id IS \'(DC2Type:uuid)\'');
        $this->addSql('ALTER TABLE title ADD CONSTRAINT FK_2B36786BA9F87BD FOREIGN KEY (title_id) REFERENCES title (id) ON DELETE SET NULL NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE title ADD CONSTRAINT FK_2B36786BBF396750 FOREIGN KEY (id) REFERENCES _acb_abstract_component (id) ON DELETE CASCADE NOT DEFERRABLE INITIALLY IMMEDIATE');
    }

    public function down(Schema $schema): void
    {}
}
