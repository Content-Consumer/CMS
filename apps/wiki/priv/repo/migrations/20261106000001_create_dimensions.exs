defmodule Wiki.Repo.Migrations.CreateDimensions do
  use Ecto.Migration

  def change do
    create table(:dimensions, primary_key: false) do
      add :id, :string, primary_key: true
      add :title, :string, null: false
      add :description, :text

      timestamps(type: :utc_datetime)
    end
  end
end
