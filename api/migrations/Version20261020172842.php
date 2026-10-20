<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20261020172842 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'The Redis watch keeps a "Redis is back" email that failed to send, so the next run retries it (#194)';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE redis_watch_state ADD recovery_email TEXT DEFAULT NULL');
    }
}
