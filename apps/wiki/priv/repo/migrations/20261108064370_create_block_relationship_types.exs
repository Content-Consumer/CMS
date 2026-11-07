defmodule Wiki.Repo.Migrations.CreateBlockRelationshipTypes do
  use Ecto.Migration

  def change do
    create table(:block_relationship_types, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :label, :string, null: false
      add :directional, :boolean, default: true, null: false
      add :dimension_id, references(:dimensions, type: :string, on_delete: :delete_all), null: true
      timestamps()
    end

    create unique_index(:block_relationship_types, [:name, :dimension_id])
  end
end
