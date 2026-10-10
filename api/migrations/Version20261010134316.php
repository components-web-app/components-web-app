<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20261010134316 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Bundle 2.0.0-alpha.12: unique index on file info (path, filter)';
    }

    public function up(Schema $schema): void
    {
        // What silverback:api-components:deduplicate-file-info does, so no manual step is needed: originals get '', the first row by id is kept.
        $this->addSql("UPDATE _acb_imagine_cached_file_metadata SET filter = '' WHERE filter IS NULL");
        $this->addSql('DELETE FROM _acb_imagine_cached_file_metadata a USING _acb_imagine_cached_file_metadata b WHERE a.path = b.path AND a.filter = b.filter AND a.id > b.id');
        $this->addSql("ALTER TABLE _acb_imagine_cached_file_metadata ALTER filter SET DEFAULT ''");
        $this->addSql('ALTER TABLE _acb_imagine_cached_file_metadata ALTER filter SET NOT NULL');
        $this->addSql('CREATE UNIQUE INDEX unique_cache_item ON _acb_imagine_cached_file_metadata (path, filter)');
    }
}
