defmodule Wiki.Repo.Migrations.AddVersionToSubBlocks do
  use Ecto.Migration

  def change do
    alter table(:sub_blocks) do
      add :block_content_version_id, references(:block_content_versions, type: :string, on_delete: :nilify_all), null: true
      add :text, :string, null: true
    end

    create index(:sub_blocks, [:block_content_version_id])
  end
end
