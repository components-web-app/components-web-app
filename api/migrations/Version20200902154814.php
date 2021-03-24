<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20200902154814 extends AbstractMigration
{
    public function getDescription() : string
    {
        return 'Initial schema';
    }

    public function up(Schema $schema) : void
    {
        $this->abortIf($this->connection->getDatabasePlatform()->getName() !== 'postgresql', 'Migration can only be executed safely on \'postgresql\'.');

        $this->addSql('CREATE TABLE "user" (id UUID NOT NULL, username VARCHAR(255) NOT NULL, email_address VARCHAR(255) NOT NULL, roles TEXT NOT NULL, enabled BOOLEAN NOT NULL, password VARCHAR(255) NOT NULL, new_password_confirmation_token VARCHAR(255) DEFAULT NULL, password_requested_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NULL, password_updated_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NULL, new_email_address VARCHAR(255) DEFAULT NULL, new_email_verification_token VARCHAR(255) DEFAULT NULL, new_email_address_change_requested_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NULL, email_address_verified BOOLEAN NOT NULL, restore_access_token VARCHAR(255) DEFAULT NULL, email_last_updated_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NULL, created_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL, modified_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL, PRIMARY KEY(id))');
        $this->addSql('CREATE INDEX username_idx ON "user" (username)');
        $this->addSql('CREATE INDEX email_address_idx ON "user" (email_address)');
        $this->addSql('COMMENT ON COLUMN "user".id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN "user".roles IS \'(DC2Type:array)\'');
        $this->addSql('COMMENT ON COLUMN "user".created_at IS \'(DC2Type:datetime_immutable)\'');
        $this->addSql('CREATE TABLE blog_article_data (id UUID NOT NULL, html_content_id UUID DEFAULT NULL, PRIMARY KEY(id))');
        $this->addSql('CREATE INDEX IDX_476D9BE5414CCF0D ON blog_article_data (html_content_id)');
        $this->addSql('COMMENT ON COLUMN blog_article_data.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN blog_article_data.html_content_id IS \'(DC2Type:uuid)\'');
        $this->addSql('CREATE TABLE refresh_token (id UUID NOT NULL, user_id UUID NOT NULL, created_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL, expired_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL, PRIMARY KEY(id))');
        $this->addSql('CREATE INDEX IDX_C74F2195A76ED395 ON refresh_token (user_id)');
        $this->addSql('COMMENT ON COLUMN refresh_token.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN refresh_token.user_id IS \'(DC2Type:uuid)\'');
        $this->addSql('CREATE TABLE _acb_route (id UUID NOT NULL, redirect UUID DEFAULT NULL, route VARCHAR(255) NOT NULL, name VARCHAR(255) NOT NULL, created_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL, modified_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL, PRIMARY KEY(id))');
        $this->addSql('CREATE UNIQUE INDEX UNIQ_9BFEB7862C42079 ON _acb_route (route)');
        $this->addSql('CREATE UNIQUE INDEX UNIQ_9BFEB7865E237E06 ON _acb_route (name)');
        $this->addSql('CREATE INDEX IDX_9BFEB786C30C9E2B ON _acb_route (redirect)');
        $this->addSql('COMMENT ON COLUMN _acb_route.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_route.redirect IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_route.created_at IS \'(DC2Type:datetime_immutable)\'');
        $this->addSql('CREATE TABLE _acb_imagine_cached_file_metadata (id UUID NOT NULL, path VARCHAR(255) NOT NULL, mime_type VARCHAR(255) NOT NULL, file_size INT NOT NULL, width INT DEFAULT NULL, height INT DEFAULT NULL, filter VARCHAR(255) DEFAULT NULL, PRIMARY KEY(id))');
        $this->addSql('CREATE UNIQUE INDEX unique_cache_item ON _acb_imagine_cached_file_metadata (path, filter)');
        $this->addSql('COMMENT ON COLUMN _acb_imagine_cached_file_metadata.id IS \'(DC2Type:uuid)\'');
        $this->addSql('CREATE TABLE _acb_page (id UUID NOT NULL, parent_route_id UUID DEFAULT NULL, route_id UUID DEFAULT NULL, layout_id UUID DEFAULT NULL, created_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL, modified_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL, reference VARCHAR(255) NOT NULL, nested BOOLEAN NOT NULL, title VARCHAR(255) DEFAULT NULL, meta_description VARCHAR(255) DEFAULT NULL, ui_component VARCHAR(255) DEFAULT NULL, ui_class_names JSON DEFAULT NULL, PRIMARY KEY(id))');
        $this->addSql('CREATE UNIQUE INDEX UNIQ_27CCF323AEA34913 ON _acb_page (reference)');
        $this->addSql('CREATE UNIQUE INDEX UNIQ_27CCF323AB211837 ON _acb_page (parent_route_id)');
        $this->addSql('CREATE UNIQUE INDEX UNIQ_27CCF32334ECB4E6 ON _acb_page (route_id)');
        $this->addSql('CREATE INDEX IDX_27CCF3238C22AA1A ON _acb_page (layout_id)');
        $this->addSql('COMMENT ON COLUMN _acb_page.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_page.parent_route_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_page.route_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_page.layout_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_page.created_at IS \'(DC2Type:datetime_immutable)\'');
        $this->addSql('CREATE TABLE _acb_page_component_collection (page_id UUID NOT NULL, component_collection_id UUID NOT NULL, PRIMARY KEY(page_id, component_collection_id))');
        $this->addSql('CREATE INDEX IDX_31CA1457C4663E4 ON _acb_page_component_collection (page_id)');
        $this->addSql('CREATE INDEX IDX_31CA145772E4DA89 ON _acb_page_component_collection (component_collection_id)');
        $this->addSql('COMMENT ON COLUMN _acb_page_component_collection.page_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_page_component_collection.component_collection_id IS \'(DC2Type:uuid)\'');
        $this->addSql('CREATE TABLE _acb_abstract_component (id UUID NOT NULL, html_content_id UUID DEFAULT NULL, ui_component VARCHAR(255) DEFAULT NULL, ui_class_names JSON DEFAULT NULL, dtype VARCHAR(255) NOT NULL, html TEXT DEFAULT NULL, published_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NULL, resource_class VARCHAR(255) DEFAULT NULL, per_page INT DEFAULT NULL, default_query_parameters JSON DEFAULT NULL, form_type VARCHAR(255) DEFAULT NULL, created_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NULL, modified_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NULL, PRIMARY KEY(id))');
        $this->addSql('CREATE INDEX IDX_4EBC1A19414CCF0D ON _acb_abstract_component (html_content_id)');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_component.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_component.html_content_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_component.created_at IS \'(DC2Type:datetime_immutable)\'');
        $this->addSql('CREATE TABLE _acb_abstract_component_component_collection (abstract_component_id UUID NOT NULL, component_collection_id UUID NOT NULL, PRIMARY KEY(abstract_component_id, component_collection_id))');
        $this->addSql('CREATE INDEX IDX_F79F072671C016CE ON _acb_abstract_component_component_collection (abstract_component_id)');
        $this->addSql('CREATE INDEX IDX_F79F072672E4DA89 ON _acb_abstract_component_component_collection (component_collection_id)');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_component_component_collection.abstract_component_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_component_component_collection.component_collection_id IS \'(DC2Type:uuid)\'');
        $this->addSql('CREATE TABLE _acb_abstract_page_data (id UUID NOT NULL, route_id UUID DEFAULT NULL, parent_route_id UUID DEFAULT NULL, page_id UUID NOT NULL, created_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL, modified_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL, nested BOOLEAN NOT NULL, title VARCHAR(255) NOT NULL, meta_description VARCHAR(255) DEFAULT NULL, dtype VARCHAR(255) NOT NULL, PRIMARY KEY(id))');
        $this->addSql('CREATE UNIQUE INDEX UNIQ_2D7554F734ECB4E6 ON _acb_abstract_page_data (route_id)');
        $this->addSql('CREATE INDEX IDX_2D7554F7AB211837 ON _acb_abstract_page_data (parent_route_id)');
        $this->addSql('CREATE INDEX IDX_2D7554F7C4663E4 ON _acb_abstract_page_data (page_id)');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_page_data.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_page_data.route_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_page_data.parent_route_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_page_data.page_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_page_data.created_at IS \'(DC2Type:datetime_immutable)\'');
        $this->addSql('CREATE TABLE _acb_layout (id UUID NOT NULL, reference VARCHAR(255) NOT NULL, ui_component VARCHAR(255) DEFAULT NULL, ui_class_names JSON DEFAULT NULL, created_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL, modified_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL, PRIMARY KEY(id))');
        $this->addSql('COMMENT ON COLUMN _acb_layout.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_layout.created_at IS \'(DC2Type:datetime_immutable)\'');
        $this->addSql('CREATE TABLE _acb_layout_component_collection (layout_id UUID NOT NULL, component_collection_id UUID NOT NULL, PRIMARY KEY(layout_id, component_collection_id))');
        $this->addSql('CREATE INDEX IDX_4E7B15EC8C22AA1A ON _acb_layout_component_collection (layout_id)');
        $this->addSql('CREATE INDEX IDX_4E7B15EC72E4DA89 ON _acb_layout_component_collection (component_collection_id)');
        $this->addSql('COMMENT ON COLUMN _acb_layout_component_collection.layout_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_layout_component_collection.component_collection_id IS \'(DC2Type:uuid)\'');
        $this->addSql('CREATE TABLE _acb_component_collection (id UUID NOT NULL, reference VARCHAR(255) NOT NULL, location VARCHAR(255) NOT NULL, allowed_components TEXT DEFAULT NULL, created_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL, modified_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL, PRIMARY KEY(id))');
        $this->addSql('CREATE UNIQUE INDEX UNIQ_B0F05E8CAEA34913 ON _acb_component_collection (reference)');
        $this->addSql('COMMENT ON COLUMN _acb_component_collection.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_component_collection.allowed_components IS \'(DC2Type:array)\'');
        $this->addSql('COMMENT ON COLUMN _acb_component_collection.created_at IS \'(DC2Type:datetime_immutable)\'');
        $this->addSql('CREATE TABLE _acb_component_position (id UUID NOT NULL, component_collection_id UUID NOT NULL, component_id UUID DEFAULT NULL, sort_value INT NOT NULL, page_data_property VARCHAR(255) DEFAULT NULL, created_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL, modified_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL, PRIMARY KEY(id))');
        $this->addSql('CREATE INDEX IDX_D6FC279672E4DA89 ON _acb_component_position (component_collection_id)');
        $this->addSql('CREATE INDEX IDX_D6FC2796E2ABAFFF ON _acb_component_position (component_id)');
        $this->addSql('COMMENT ON COLUMN _acb_component_position.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_component_position.component_collection_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_component_position.component_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_component_position.created_at IS \'(DC2Type:datetime_immutable)\'');
        $this->addSql('ALTER TABLE blog_article_data ADD CONSTRAINT FK_476D9BE5414CCF0D FOREIGN KEY (html_content_id) REFERENCES _acb_abstract_component (id) NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE blog_article_data ADD CONSTRAINT FK_476D9BE5BF396750 FOREIGN KEY (id) REFERENCES _acb_abstract_page_data (id) ON DELETE CASCADE NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE refresh_token ADD CONSTRAINT FK_C74F2195A76ED395 FOREIGN KEY (user_id) REFERENCES "user" (id) NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_route ADD CONSTRAINT FK_9BFEB786C30C9E2B FOREIGN KEY (redirect) REFERENCES _acb_route (id) ON DELETE SET NULL NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_page ADD CONSTRAINT FK_27CCF323AB211837 FOREIGN KEY (parent_route_id) REFERENCES _acb_route (id) NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_page ADD CONSTRAINT FK_27CCF32334ECB4E6 FOREIGN KEY (route_id) REFERENCES _acb_route (id) NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_page ADD CONSTRAINT FK_27CCF3238C22AA1A FOREIGN KEY (layout_id) REFERENCES _acb_layout (id) ON DELETE SET NULL NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_page_component_collection ADD CONSTRAINT FK_31CA1457C4663E4 FOREIGN KEY (page_id) REFERENCES _acb_page (id) ON DELETE CASCADE NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_page_component_collection ADD CONSTRAINT FK_31CA145772E4DA89 FOREIGN KEY (component_collection_id) REFERENCES _acb_component_collection (id) ON DELETE CASCADE NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_abstract_component ADD CONSTRAINT FK_4EBC1A19414CCF0D FOREIGN KEY (html_content_id) REFERENCES _acb_abstract_component (id) ON DELETE SET NULL NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_abstract_component_component_collection ADD CONSTRAINT FK_F79F072671C016CE FOREIGN KEY (abstract_component_id) REFERENCES _acb_abstract_component (id) ON DELETE CASCADE NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_abstract_component_component_collection ADD CONSTRAINT FK_F79F072672E4DA89 FOREIGN KEY (component_collection_id) REFERENCES _acb_component_collection (id) ON DELETE CASCADE NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_abstract_page_data ADD CONSTRAINT FK_2D7554F734ECB4E6 FOREIGN KEY (route_id) REFERENCES _acb_route (id) NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_abstract_page_data ADD CONSTRAINT FK_2D7554F7AB211837 FOREIGN KEY (parent_route_id) REFERENCES _acb_route (id) NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_abstract_page_data ADD CONSTRAINT FK_2D7554F7C4663E4 FOREIGN KEY (page_id) REFERENCES _acb_page (id) NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_layout_component_collection ADD CONSTRAINT FK_4E7B15EC8C22AA1A FOREIGN KEY (layout_id) REFERENCES _acb_layout (id) ON DELETE CASCADE NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_layout_component_collection ADD CONSTRAINT FK_4E7B15EC72E4DA89 FOREIGN KEY (component_collection_id) REFERENCES _acb_component_collection (id) ON DELETE CASCADE NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_component_position ADD CONSTRAINT FK_D6FC279672E4DA89 FOREIGN KEY (component_collection_id) REFERENCES _acb_component_collection (id) ON DELETE CASCADE NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('ALTER TABLE _acb_component_position ADD CONSTRAINT FK_D6FC2796E2ABAFFF FOREIGN KEY (component_id) REFERENCES _acb_abstract_component (id) ON DELETE CASCADE NOT DEFERRABLE INITIALLY IMMEDIATE');
    }

    public function down(Schema $schema) : void
    {
        $this->abortIf($this->connection->getDatabasePlatform()->getName() !== 'postgresql', 'Migration can only be executed safely on \'postgresql\'.');

        $this->addSql('ALTER TABLE refresh_token DROP CONSTRAINT FK_C74F2195A76ED395');
        $this->addSql('ALTER TABLE _acb_route DROP CONSTRAINT FK_9BFEB786C30C9E2B');
        $this->addSql('ALTER TABLE _acb_page DROP CONSTRAINT FK_27CCF323AB211837');
        $this->addSql('ALTER TABLE _acb_page DROP CONSTRAINT FK_27CCF32334ECB4E6');
        $this->addSql('ALTER TABLE _acb_abstract_page_data DROP CONSTRAINT FK_2D7554F734ECB4E6');
        $this->addSql('ALTER TABLE _acb_abstract_page_data DROP CONSTRAINT FK_2D7554F7AB211837');
        $this->addSql('ALTER TABLE _acb_page_component_collection DROP CONSTRAINT FK_31CA1457C4663E4');
        $this->addSql('ALTER TABLE _acb_abstract_page_data DROP CONSTRAINT FK_2D7554F7C4663E4');
        $this->addSql('ALTER TABLE blog_article_data DROP CONSTRAINT FK_476D9BE5414CCF0D');
        $this->addSql('ALTER TABLE _acb_abstract_component DROP CONSTRAINT FK_4EBC1A19414CCF0D');
        $this->addSql('ALTER TABLE _acb_abstract_component_component_collection DROP CONSTRAINT FK_F79F072671C016CE');
        $this->addSql('ALTER TABLE _acb_component_position DROP CONSTRAINT FK_D6FC2796E2ABAFFF');
        $this->addSql('ALTER TABLE blog_article_data DROP CONSTRAINT FK_476D9BE5BF396750');
        $this->addSql('ALTER TABLE _acb_page DROP CONSTRAINT FK_27CCF3238C22AA1A');
        $this->addSql('ALTER TABLE _acb_layout_component_collection DROP CONSTRAINT FK_4E7B15EC8C22AA1A');
        $this->addSql('ALTER TABLE _acb_page_component_collection DROP CONSTRAINT FK_31CA145772E4DA89');
        $this->addSql('ALTER TABLE _acb_abstract_component_component_collection DROP CONSTRAINT FK_F79F072672E4DA89');
        $this->addSql('ALTER TABLE _acb_layout_component_collection DROP CONSTRAINT FK_4E7B15EC72E4DA89');
        $this->addSql('ALTER TABLE _acb_component_position DROP CONSTRAINT FK_D6FC279672E4DA89');
        $this->addSql('DROP TABLE "user"');
        $this->addSql('DROP TABLE blog_article_data');
        $this->addSql('DROP TABLE refresh_token');
        $this->addSql('DROP TABLE _acb_route');
        $this->addSql('DROP TABLE _acb_imagine_cached_file_metadata');
        $this->addSql('DROP TABLE _acb_page');
        $this->addSql('DROP TABLE _acb_page_component_collection');
        $this->addSql('DROP TABLE _acb_abstract_component');
        $this->addSql('DROP TABLE _acb_abstract_component_component_collection');
        $this->addSql('DROP TABLE _acb_abstract_page_data');
        $this->addSql('DROP TABLE _acb_layout');
        $this->addSql('DROP TABLE _acb_layout_component_collection');
        $this->addSql('DROP TABLE _acb_component_collection');
        $this->addSql('DROP TABLE _acb_component_position');
    }
}
