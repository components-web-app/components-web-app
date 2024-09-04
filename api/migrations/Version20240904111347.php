<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20240904111347 extends AbstractMigration
{
    public function getDescription(): string
    {
        return '';
    }

    public function up(Schema $schema): void
    {
        // this up() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE blog_article_data ADD image_id UUID DEFAULT NULL');
        $this->addSql('COMMENT ON COLUMN blog_article_data.image_id IS \'(DC2Type:uuid)\'');
        $this->addSql('ALTER TABLE blog_article_data ADD CONSTRAINT FK_476D9BE53DA5256D FOREIGN KEY (image_id) REFERENCES image (id) ON DELETE SET NULL NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('CREATE INDEX IDX_476D9BE53DA5256D ON blog_article_data (image_id)');
    }

    public function down(Schema $schema): void
    {}
}
