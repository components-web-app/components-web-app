<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20261020171138 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'The Redis watch remembers the release revision, so a restart caused by a deploy sends no email (#85)';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE redis_watch_state ADD release_revision VARCHAR(32) DEFAULT NULL');
    }
}
