<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20260616070213 extends AbstractMigration
{
    public function getDescription(): string
    {
        return '';
    }

    public function up(Schema $schema): void
    {
        // this up() migration is auto-generated, please modify it to your needs
        $this->addSql('CREATE TABLE nested_page_data (intro_content_id UUID DEFAULT NULL, id UUID NOT NULL, PRIMARY KEY (id))');
        $this->addSql('CREATE INDEX IDX_BC5F93ED580D710B ON nested_page_data (intro_content_id)');
        $this->addSql('CREATE TABLE nested_sub_page_data (body_content_id UUID DEFAULT NULL, id UUID NOT NULL, PRIMARY KEY (id))');
        $this->addSql('CREATE INDEX IDX_95F677181CE7259E ON nested_sub_page_data (body_content_id)');
        $this->addSql('ALTER TABLE nested_page_data ADD CONSTRAINT FK_BC5F93ED580D710B FOREIGN KEY (intro_content_id) REFERENCES html_content (id) ON DELETE SET NULL NOT DEFERRABLE');
        $this->addSql('ALTER TABLE nested_page_data ADD CONSTRAINT FK_BC5F93EDBF396750 FOREIGN KEY (id) REFERENCES _acb_abstract_page_data (id) ON DELETE CASCADE');
        $this->addSql('ALTER TABLE nested_sub_page_data ADD CONSTRAINT FK_95F677181CE7259E FOREIGN KEY (body_content_id) REFERENCES html_content (id) ON DELETE SET NULL NOT DEFERRABLE');
        $this->addSql('ALTER TABLE nested_sub_page_data ADD CONSTRAINT FK_95F67718BF396750 FOREIGN KEY (id) REFERENCES _acb_abstract_page_data (id) ON DELETE CASCADE');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_component.id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_component_component_group.abstract_component_id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_component_component_group.component_group_id IS \'\'');
        $this->addSql('ALTER TABLE _acb_abstract_page_data DROP CONSTRAINT fk_2d7554f7ab211837');
        $this->addSql('DROP INDEX idx_2d7554f7ab211837');
        $this->addSql('ALTER TABLE _acb_abstract_page_data ADD parent_page_id UUID DEFAULT NULL');
        $this->addSql('ALTER TABLE _acb_abstract_page_data ADD parent_page_data_id UUID DEFAULT NULL');
        $this->addSql('ALTER TABLE _acb_abstract_page_data DROP parent_route_id');
        $this->addSql('ALTER TABLE _acb_abstract_page_data DROP nested');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_page_data.id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_page_data.route_id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_page_data.page_id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_page_data.created_at IS \'\'');
        $this->addSql('ALTER TABLE _acb_abstract_page_data ADD CONSTRAINT FK_2D7554F77E0E17A2 FOREIGN KEY (parent_page_id) REFERENCES _acb_page (id) ON DELETE SET NULL NOT DEFERRABLE');
        $this->addSql('ALTER TABLE _acb_abstract_page_data ADD CONSTRAINT FK_2D7554F79DFB1787 FOREIGN KEY (parent_page_data_id) REFERENCES _acb_abstract_page_data (id) ON DELETE SET NULL NOT DEFERRABLE');
        $this->addSql('CREATE INDEX IDX_2D7554F77E0E17A2 ON _acb_abstract_page_data (parent_page_id)');
        $this->addSql('CREATE INDEX IDX_2D7554F79DFB1787 ON _acb_abstract_page_data (parent_page_data_id)');
        $this->addSql('COMMENT ON COLUMN _acb_collection.id IS \'\'');
        $this->addSql('ALTER TABLE _acb_component_group ALTER allowed_components TYPE JSON USING allowed_components::json');
        $this->addSql('COMMENT ON COLUMN _acb_component_group.id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_component_group.allowed_components IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_component_group.created_at IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_component_position.id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_component_position.component_group_id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_component_position.component_id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_component_position.created_at IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_form.id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_form.created_at IS \'\'');
        $this->addSql('DROP INDEX unique_cache_item');
        $this->addSql('COMMENT ON COLUMN _acb_imagine_cached_file_metadata.id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_layout.id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_layout.created_at IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_layout_component_group.layout_id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_layout_component_group.component_group_id IS \'\'');
        $this->addSql('ALTER TABLE _acb_page DROP CONSTRAINT fk_27ccf323ab211837');
        $this->addSql('DROP INDEX uniq_27ccf323ab211837');
        $this->addSql('ALTER TABLE _acb_page ADD parent_page_id UUID DEFAULT NULL');
        $this->addSql('ALTER TABLE _acb_page ADD parent_page_data_id UUID DEFAULT NULL');
        $this->addSql('ALTER TABLE _acb_page DROP parent_route_id');
        $this->addSql('ALTER TABLE _acb_page DROP nested');
        $this->addSql('COMMENT ON COLUMN _acb_page.id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_page.route_id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_page.layout_id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_page.created_at IS \'\'');
        $this->addSql('ALTER TABLE _acb_page ADD CONSTRAINT FK_27CCF3237E0E17A2 FOREIGN KEY (parent_page_id) REFERENCES _acb_page (id) ON DELETE SET NULL NOT DEFERRABLE');
        $this->addSql('ALTER TABLE _acb_page ADD CONSTRAINT FK_27CCF3239DFB1787 FOREIGN KEY (parent_page_data_id) REFERENCES _acb_abstract_page_data (id) ON DELETE SET NULL NOT DEFERRABLE');
        $this->addSql('CREATE INDEX IDX_27CCF3237E0E17A2 ON _acb_page (parent_page_id)');
        $this->addSql('CREATE INDEX IDX_27CCF3239DFB1787 ON _acb_page (parent_page_data_id)');
        $this->addSql('COMMENT ON COLUMN _acb_page_component_group.page_id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_page_component_group.component_group_id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_route.id IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_route.redirect IS \'\'');
        $this->addSql('COMMENT ON COLUMN _acb_route.created_at IS \'\'');
        $this->addSql('COMMENT ON COLUMN blog_article_data.id IS \'\'');
        $this->addSql('COMMENT ON COLUMN blog_article_data.html_content_id IS \'\'');
        $this->addSql('COMMENT ON COLUMN blog_article_data.image_id IS \'\'');
        $this->addSql('ALTER TABLE html_content DROP CONSTRAINT fk_6a910e25414ccf0d');
        $this->addSql('DROP INDEX uniq_6a910e25414ccf0d');
        $this->addSql('ALTER TABLE html_content ADD published_resource_id UUID DEFAULT NULL');
        $this->addSql('ALTER TABLE html_content DROP html_content_id');
        $this->addSql('COMMENT ON COLUMN html_content.id IS \'\'');
        $this->addSql('ALTER TABLE html_content ADD CONSTRAINT FK_6A910E256AAFFC9A FOREIGN KEY (published_resource_id) REFERENCES html_content (id) ON DELETE SET NULL');
        $this->addSql('CREATE UNIQUE INDEX UNIQ_6A910E256AAFFC9A ON html_content (published_resource_id)');
        $this->addSql('ALTER TABLE image DROP CONSTRAINT fk_c53d045f3da5256d');
        $this->addSql('DROP INDEX uniq_c53d045f3da5256d');
        $this->addSql('ALTER TABLE image ADD published_resource_id UUID DEFAULT NULL');
        $this->addSql('ALTER TABLE image DROP image_id');
        $this->addSql('COMMENT ON COLUMN image.id IS \'\'');
        $this->addSql('ALTER TABLE image ADD CONSTRAINT FK_C53D045F6AAFFC9A FOREIGN KEY (published_resource_id) REFERENCES image (id) ON DELETE SET NULL');
        $this->addSql('CREATE UNIQUE INDEX UNIQ_C53D045F6AAFFC9A ON image (published_resource_id)');
        $this->addSql('ALTER TABLE navigation_link DROP CONSTRAINT fk_12c4c83eb260c02');
        $this->addSql('DROP INDEX uniq_12c4c83eb260c02');
        $this->addSql('ALTER TABLE navigation_link ADD published_resource_id UUID DEFAULT NULL');
        $this->addSql('ALTER TABLE navigation_link DROP navigation_link_id');
        $this->addSql('COMMENT ON COLUMN navigation_link.id IS \'\'');
        $this->addSql('COMMENT ON COLUMN navigation_link.route_id IS \'\'');
        $this->addSql('ALTER TABLE navigation_link ADD CONSTRAINT FK_12C4C836AAFFC9A FOREIGN KEY (published_resource_id) REFERENCES navigation_link (id) ON DELETE SET NULL');
        $this->addSql('CREATE UNIQUE INDEX UNIQ_12C4C836AAFFC9A ON navigation_link (published_resource_id)');
        $this->addSql('COMMENT ON COLUMN refresh_token.id IS \'\'');
        $this->addSql('COMMENT ON COLUMN refresh_token.user_id IS \'\'');
        $this->addSql('ALTER TABLE title DROP CONSTRAINT fk_2b36786ba9f87bd');
        $this->addSql('DROP INDEX uniq_2b36786ba9f87bd');
        $this->addSql('ALTER TABLE title ADD published_resource_id UUID DEFAULT NULL');
        $this->addSql('ALTER TABLE title DROP title_id');
        $this->addSql('COMMENT ON COLUMN title.id IS \'\'');
        $this->addSql('ALTER TABLE title ADD CONSTRAINT FK_2B36786B6AAFFC9A FOREIGN KEY (published_resource_id) REFERENCES title (id) ON DELETE SET NULL');
        $this->addSql('CREATE UNIQUE INDEX UNIQ_2B36786B6AAFFC9A ON title (published_resource_id)');
        $this->addSql('DROP INDEX username_idx');
        $this->addSql('DROP INDEX email_address_idx');
        $this->addSql('ALTER TABLE "user" ALTER roles TYPE JSON USING roles::json');
        $this->addSql('COMMENT ON COLUMN "user".id IS \'\'');
        $this->addSql('COMMENT ON COLUMN "user".roles IS \'\'');
        $this->addSql('COMMENT ON COLUMN "user".created_at IS \'\'');
    }

    public function down(Schema $schema): void
    {
        // this down() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE nested_page_data DROP CONSTRAINT FK_BC5F93ED580D710B');
        $this->addSql('ALTER TABLE nested_page_data DROP CONSTRAINT FK_BC5F93EDBF396750');
        $this->addSql('ALTER TABLE nested_sub_page_data DROP CONSTRAINT FK_95F677181CE7259E');
        $this->addSql('ALTER TABLE nested_sub_page_data DROP CONSTRAINT FK_95F67718BF396750');
        $this->addSql('DROP TABLE nested_page_data');
        $this->addSql('DROP TABLE nested_sub_page_data');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_component.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_component_component_group.abstract_component_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_component_component_group.component_group_id IS \'(DC2Type:uuid)\'');
        $this->addSql('ALTER TABLE _acb_abstract_page_data DROP CONSTRAINT FK_2D7554F77E0E17A2');
        $this->addSql('ALTER TABLE _acb_abstract_page_data DROP CONSTRAINT FK_2D7554F79DFB1787');
        $this->addSql('DROP INDEX IDX_2D7554F77E0E17A2');
        $this->addSql('DROP INDEX IDX_2D7554F79DFB1787');
        $this->addSql('ALTER TABLE _acb_abstract_page_data ADD parent_route_id UUID DEFAULT NULL');
        $this->addSql('ALTER TABLE _acb_abstract_page_data ADD nested BOOLEAN NOT NULL');
        $this->addSql('ALTER TABLE _acb_abstract_page_data DROP parent_page_id');
        $this->addSql('ALTER TABLE _acb_abstract_page_data DROP parent_page_data_id');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_page_data.parent_route_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_page_data.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_page_data.created_at IS \'(DC2Type:datetime_immutable)\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_page_data.route_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_abstract_page_data.page_id IS \'(DC2Type:uuid)\'');
        $this->addSql('ALTER TABLE _acb_abstract_page_data ADD CONSTRAINT fk_2d7554f7ab211837 FOREIGN KEY (parent_route_id) REFERENCES _acb_route (id) NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('CREATE INDEX idx_2d7554f7ab211837 ON _acb_abstract_page_data (parent_route_id)');
        $this->addSql('COMMENT ON COLUMN _acb_collection.id IS \'(DC2Type:uuid)\'');
        $this->addSql('ALTER TABLE _acb_component_group ALTER allowed_components TYPE TEXT');
        $this->addSql('COMMENT ON COLUMN _acb_component_group.allowed_components IS \'(DC2Type:array)\'');
        $this->addSql('COMMENT ON COLUMN _acb_component_group.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_component_group.created_at IS \'(DC2Type:datetime_immutable)\'');
        $this->addSql('COMMENT ON COLUMN _acb_component_position.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_component_position.created_at IS \'(DC2Type:datetime_immutable)\'');
        $this->addSql('COMMENT ON COLUMN _acb_component_position.component_group_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_component_position.component_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_form.created_at IS \'(DC2Type:datetime_immutable)\'');
        $this->addSql('COMMENT ON COLUMN _acb_form.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_imagine_cached_file_metadata.id IS \'(DC2Type:uuid)\'');
        $this->addSql('CREATE UNIQUE INDEX unique_cache_item ON _acb_imagine_cached_file_metadata (path, filter)');
        $this->addSql('COMMENT ON COLUMN _acb_layout.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_layout.created_at IS \'(DC2Type:datetime_immutable)\'');
        $this->addSql('COMMENT ON COLUMN _acb_layout_component_group.layout_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_layout_component_group.component_group_id IS \'(DC2Type:uuid)\'');
        $this->addSql('ALTER TABLE _acb_page DROP CONSTRAINT FK_27CCF3237E0E17A2');
        $this->addSql('ALTER TABLE _acb_page DROP CONSTRAINT FK_27CCF3239DFB1787');
        $this->addSql('DROP INDEX IDX_27CCF3237E0E17A2');
        $this->addSql('DROP INDEX IDX_27CCF3239DFB1787');
        $this->addSql('ALTER TABLE _acb_page ADD parent_route_id UUID DEFAULT NULL');
        $this->addSql('ALTER TABLE _acb_page ADD nested BOOLEAN NOT NULL');
        $this->addSql('ALTER TABLE _acb_page DROP parent_page_id');
        $this->addSql('ALTER TABLE _acb_page DROP parent_page_data_id');
        $this->addSql('COMMENT ON COLUMN _acb_page.parent_route_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_page.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_page.created_at IS \'(DC2Type:datetime_immutable)\'');
        $this->addSql('COMMENT ON COLUMN _acb_page.route_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_page.layout_id IS \'(DC2Type:uuid)\'');
        $this->addSql('ALTER TABLE _acb_page ADD CONSTRAINT fk_27ccf323ab211837 FOREIGN KEY (parent_route_id) REFERENCES _acb_route (id) ON DELETE SET NULL NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('CREATE UNIQUE INDEX uniq_27ccf323ab211837 ON _acb_page (parent_route_id)');
        $this->addSql('COMMENT ON COLUMN _acb_page_component_group.page_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_page_component_group.component_group_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_route.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN _acb_route.created_at IS \'(DC2Type:datetime_immutable)\'');
        $this->addSql('COMMENT ON COLUMN _acb_route.redirect IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN blog_article_data.html_content_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN blog_article_data.image_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN blog_article_data.id IS \'(DC2Type:uuid)\'');
        $this->addSql('ALTER TABLE html_content DROP CONSTRAINT FK_6A910E256AAFFC9A');
        $this->addSql('DROP INDEX UNIQ_6A910E256AAFFC9A');
        $this->addSql('ALTER TABLE html_content ADD html_content_id UUID DEFAULT NULL');
        $this->addSql('ALTER TABLE html_content DROP published_resource_id');
        $this->addSql('COMMENT ON COLUMN html_content.html_content_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN html_content.id IS \'(DC2Type:uuid)\'');
        $this->addSql('ALTER TABLE html_content ADD CONSTRAINT fk_6a910e25414ccf0d FOREIGN KEY (html_content_id) REFERENCES html_content (id) ON DELETE SET NULL NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('CREATE UNIQUE INDEX uniq_6a910e25414ccf0d ON html_content (html_content_id)');
        $this->addSql('ALTER TABLE image DROP CONSTRAINT FK_C53D045F6AAFFC9A');
        $this->addSql('DROP INDEX UNIQ_C53D045F6AAFFC9A');
        $this->addSql('ALTER TABLE image ADD image_id UUID DEFAULT NULL');
        $this->addSql('ALTER TABLE image DROP published_resource_id');
        $this->addSql('COMMENT ON COLUMN image.image_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN image.id IS \'(DC2Type:uuid)\'');
        $this->addSql('ALTER TABLE image ADD CONSTRAINT fk_c53d045f3da5256d FOREIGN KEY (image_id) REFERENCES image (id) ON DELETE SET NULL NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('CREATE UNIQUE INDEX uniq_c53d045f3da5256d ON image (image_id)');
        $this->addSql('ALTER TABLE navigation_link DROP CONSTRAINT FK_12C4C836AAFFC9A');
        $this->addSql('DROP INDEX UNIQ_12C4C836AAFFC9A');
        $this->addSql('ALTER TABLE navigation_link ADD navigation_link_id UUID DEFAULT NULL');
        $this->addSql('ALTER TABLE navigation_link DROP published_resource_id');
        $this->addSql('COMMENT ON COLUMN navigation_link.navigation_link_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN navigation_link.route_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN navigation_link.id IS \'(DC2Type:uuid)\'');
        $this->addSql('ALTER TABLE navigation_link ADD CONSTRAINT fk_12c4c83eb260c02 FOREIGN KEY (navigation_link_id) REFERENCES navigation_link (id) ON DELETE SET NULL NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('CREATE UNIQUE INDEX uniq_12c4c83eb260c02 ON navigation_link (navigation_link_id)');
        $this->addSql('COMMENT ON COLUMN refresh_token.id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN refresh_token.user_id IS \'(DC2Type:uuid)\'');
        $this->addSql('ALTER TABLE title DROP CONSTRAINT FK_2B36786B6AAFFC9A');
        $this->addSql('DROP INDEX UNIQ_2B36786B6AAFFC9A');
        $this->addSql('ALTER TABLE title ADD title_id UUID DEFAULT NULL');
        $this->addSql('ALTER TABLE title DROP published_resource_id');
        $this->addSql('COMMENT ON COLUMN title.title_id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN title.id IS \'(DC2Type:uuid)\'');
        $this->addSql('ALTER TABLE title ADD CONSTRAINT fk_2b36786ba9f87bd FOREIGN KEY (title_id) REFERENCES title (id) ON DELETE SET NULL NOT DEFERRABLE INITIALLY IMMEDIATE');
        $this->addSql('CREATE UNIQUE INDEX uniq_2b36786ba9f87bd ON title (title_id)');
        $this->addSql('ALTER TABLE "user" ALTER roles TYPE TEXT');
        $this->addSql('COMMENT ON COLUMN "user".roles IS \'(DC2Type:array)\'');
        $this->addSql('COMMENT ON COLUMN "user".id IS \'(DC2Type:uuid)\'');
        $this->addSql('COMMENT ON COLUMN "user".created_at IS \'(DC2Type:datetime_immutable)\'');
        $this->addSql('CREATE INDEX username_idx ON "user" (username)');
        $this->addSql('CREATE INDEX email_address_idx ON "user" (email_address)');
    }
}
