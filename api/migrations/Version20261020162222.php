<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20261020162222 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'The Redis watch job\'s state (#85)';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('CREATE TABLE redis_watch_state (id SMALLINT NOT NULL, redis_run_id VARCHAR(64) DEFAULT NULL, last_ok_at TIMESTAMP(0) WITH TIME ZONE DEFAULT NULL, down_since TIMESTAMP(0) WITH TIME ZONE DEFAULT NULL, down_reason TEXT DEFAULT NULL, down_notified BOOLEAN NOT NULL, edge_purge_pending BOOLEAN NOT NULL, checked_at TIMESTAMP(0) WITH TIME ZONE DEFAULT NULL, PRIMARY KEY (id))');
    }
}
