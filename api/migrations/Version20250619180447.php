<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20250619180447 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'ACB User table update';
    }

    public function up(Schema $schema): void
    {
        // this up() migration is auto-generated, please modify it to your needs
        $this->addSql(<<<'SQL'
            ALTER TABLE "user" ADD email_address_verification_requested_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NULL
        SQL);
        $this->addSql(<<<'SQL'
            ALTER TABLE "user" RENAME COLUMN restore_access_token TO email_address_verify_token
        SQL);
    }

    public function down(Schema $schema): void
    {
    }
}
