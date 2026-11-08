defmodule Wiki.Repo.Migrations.CreateBlockContentVersions do
  use Ecto.Migration

  def up do
    create table(:block_content_versions, primary_key: false) do
      add :id, :string, primary_key: true
      add :block_id, references(:text_blocks, type: :string, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :version_num, :integer, null: false
      timestamps(updated_at: false)
    end

    create index(:block_content_versions, [:block_id])
    create unique_index(:block_content_versions, [:block_id, :version_num])

    # Backfill version 1 for all existing blocks using SQL (no UXID needed for legacy rows)
    execute """
      INSERT INTO block_content_versions (id, block_id, content, version_num, inserted_at)
      SELECT
        concat('bcv_legacy_', replace(gen_random_uuid()::text, '-', '')),
        tb.id,
        tbc.content,
        1,
        NOW()
      FROM text_blocks tb
      JOIN text_block_contents tbc ON tb.content_id = tbc.id
    """
  end

  def down do
    drop table(:block_content_versions)
  end
end
