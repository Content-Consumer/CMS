defmodule Wiki.Repo.Migrations.CreateDimensionActivityTypes do
  use Ecto.Migration

  def change do
    create table(:dimension_activity_types, primary_key: false) do
      add :id, :string, primary_key: true

      add :dimension_id,
          references(:dimensions, type: :string, on_delete: :delete_all),
          null: false

      add :name, :string, null: false
      add :type, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:dimension_activity_types, [:dimension_id])
    create unique_index(:dimension_activity_types, [:dimension_id, :type, :name])
  end
end
