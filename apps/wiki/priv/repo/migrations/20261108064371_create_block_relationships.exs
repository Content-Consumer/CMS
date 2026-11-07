defmodule Wiki.Repo.Migrations.CreateBlockRelationships do
  use Ecto.Migration

  def change do
    create table(:block_relationships, primary_key: false) do
      add :id, :string, primary_key: true
      add :source_block_id, references(:text_blocks, type: :string, on_delete: :delete_all), null: false
      add :target_block_id, references(:text_blocks, type: :string, on_delete: :delete_all), null: false
      add :type_id, references(:block_relationship_types, type: :string, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:block_relationships, [:source_block_id, :target_block_id, :type_id])
    create index(:block_relationships, [:source_block_id])
    create index(:block_relationships, [:target_block_id])
  end
end
