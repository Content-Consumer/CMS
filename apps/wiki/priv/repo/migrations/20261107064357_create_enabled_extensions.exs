defmodule Wiki.Repo.Migrations.CreateEnabledExtensions do
  use Ecto.Migration

  def change do
    create table(:enabled_extensions, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:enabled_extensions, [:name])
  end
end
