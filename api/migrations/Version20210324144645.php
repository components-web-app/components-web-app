<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20210324144645 extends AbstractMigration
{
    public function getDescription() : string
    {
        return 'Case insensitive lookup index';
    }

    public function up(Schema $schema) : void
    {
        $this->abortIf($this->connection->getDatabasePlatform()->getName() !== 'postgresql', 'Migration can only be executed safely on \'postgresql\'.');

        $this->addSql('CREATE INDEX username_lower ON "user" (LOWER(username))');
        $this->addSql('CREATE INDEX email_address_lower ON "user" (LOWER(email_address))');
        $this->addSql('CREATE INDEX username_email_address_lower ON "user" (LOWER(username), LOWER(email_address))');
    }

    public function down(Schema $schema) : void
    {
        $this->abortIf($this->connection->getDatabasePlatform()->getName() !== 'postgresql', 'Migration can only be executed safely on \'postgresql\'.');

        $this->addSql('DROP INDEX username_lower ON "user"');
        $this->addSql('DROP INDEX email_address_lower ON "user"');
        $this->addSql('DROP INDEX username_email_address_lower ON "user"');
    }
}
