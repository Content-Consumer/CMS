defmodule Wiki.Repo.Migrations.CreateUserActivities do
  use Ecto.Migration

  def change do
    create table(:user_activities, primary_key: false) do
      add :id, :string, primary_key: true

      add :dimension_id,
          references(:dimensions, type: :string, on_delete: :delete_all),
          null: false

      add :user_id,
          references(:users, type: :string, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create index(:user_activities, [:dimension_id])
    create index(:user_activities, [:user_id])
    create unique_index(:user_activities, [:dimension_id, :user_id])
  end
end
