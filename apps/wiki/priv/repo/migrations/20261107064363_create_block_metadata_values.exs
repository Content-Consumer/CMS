defmodule Wiki.Repo.Migrations.CreateBlockMetadataValues do
  use Ecto.Migration

  def change do
    create table(:block_metadata_values, primary_key: false) do
      add :id, :string, primary_key: true

      add :block_id,
          references(:text_blocks, type: :string, on_delete: :delete_all),
          null: false

      add :field_id,
          references(:block_metadata_fields, type: :string, on_delete: :delete_all),
          null: false

      add :value, :map, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:block_metadata_values, [:block_id])
    create index(:block_metadata_values, [:field_id])
    create unique_index(:block_metadata_values, [:block_id, :field_id])
  end
end
