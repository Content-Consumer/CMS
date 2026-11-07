defmodule Wiki.Repo.Migrations.CreateBlockMetadataFields do
  use Ecto.Migration

  def change do
    create table(:block_metadata_fields, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :label, :string, null: false
      add :type, :string, null: false

      add :dimension_id,
          references(:dimensions, type: :string, on_delete: :delete_all),
          null: true

      timestamps(type: :utc_datetime)
    end

    create index(:block_metadata_fields, [:dimension_id])
    create unique_index(:block_metadata_fields, [:name, :dimension_id])
  end
end
