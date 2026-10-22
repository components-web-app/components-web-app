<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20261022192418 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Bundle 2.0.0-alpha.37: collaboration_state, the stored Yjs state for collaborative editing (#219)';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('CREATE TABLE _acb_collaboration_state (field VARCHAR(255) DEFAULT NULL, state TEXT DEFAULT NULL, html_hash VARCHAR(255) DEFAULT NULL, id UUID NOT NULL, resource_version INT DEFAULT 1 NOT NULL, component_id UUID DEFAULT NULL, page_data_id UUID DEFAULT NULL, PRIMARY KEY (id))');
        $this->addSql('CREATE UNIQUE INDEX collaboration_state_component_field ON _acb_collaboration_state (component_id, field)');
        $this->addSql('CREATE UNIQUE INDEX collaboration_state_page_data_field ON _acb_collaboration_state (page_data_id, field)');
        $this->addSql('CREATE INDEX IDX_D2BD20A3E2ABAFFF ON _acb_collaboration_state (component_id)');
        $this->addSql('CREATE INDEX IDX_D2BD20A3CD954AA9 ON _acb_collaboration_state (page_data_id)');
        $this->addSql('ALTER TABLE _acb_collaboration_state ADD CONSTRAINT FK_D2BD20A3E2ABAFFF FOREIGN KEY (component_id) REFERENCES _acb_abstract_component (id) ON DELETE CASCADE NOT DEFERRABLE');
        $this->addSql('ALTER TABLE _acb_collaboration_state ADD CONSTRAINT FK_D2BD20A3CD954AA9 FOREIGN KEY (page_data_id) REFERENCES _acb_abstract_page_data (id) ON DELETE CASCADE NOT DEFERRABLE');
    }
}
