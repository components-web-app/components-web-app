<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Route-level live / scheduled publication date, from
 * api-components-bundle#224. Nullable with a CURRENT_TIMESTAMP default so
 * existing routes are immediately live.
 */
final class Version20260921141436 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add Route.liveAt for scheduled route publication';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE _acb_route ADD live_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE _acb_route DROP live_at');
    }
}
