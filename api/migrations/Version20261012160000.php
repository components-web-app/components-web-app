<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20261012160000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Bundle 2.0.0-alpha.17: drop variant file info written before variants replaced it';
    }

    public function up(Schema $schema): void
    {
        // The bundle's alpha.17 upgrade step (api-components-bundle#421): each variant's row is read again from its stored file on the next render.
        $this->addSql("DELETE FROM _acb_imagine_cached_file_metadata WHERE filter <> ''");
    }
}
