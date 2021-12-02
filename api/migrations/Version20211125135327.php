<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20211125135327 extends AbstractMigration
{
    public function getDescription(): string
    {
        return '';
    }

    public function up(Schema $schema): void
    {
        // this up() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE blog_article_data DROP CONSTRAINT FK_476D9BE5414CCF0D');
        $this->addSql('ALTER TABLE blog_article_data ADD CONSTRAINT FK_476D9BE5414CCF0D FOREIGN KEY (html_content_id) REFERENCES _acb_abstract_component (id) ON DELETE SET NULL NOT DEFERRABLE INITIALLY IMMEDIATE');
    }

    public function down(Schema $schema): void
    {
        // this down() migration is auto-generated, please modify it to your needs
        $this->addSql('CREATE SCHEMA public');
        $this->addSql('ALTER TABLE blog_article_data DROP CONSTRAINT fk_476d9be5414ccf0d');
        $this->addSql('ALTER TABLE blog_article_data ADD CONSTRAINT fk_476d9be5414ccf0d FOREIGN KEY (html_content_id) REFERENCES _acb_abstract_component (id) NOT DEFERRABLE INITIALLY IMMEDIATE');
    }
}
