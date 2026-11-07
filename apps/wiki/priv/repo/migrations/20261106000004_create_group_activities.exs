defmodule Wiki.Repo.Migrations.CreateGroupActivities do
  use Ecto.Migration

  def change do
    create table(:group_activities, primary_key: false) do
      add :id, :string, primary_key: true

      add :dimension_id,
          references(:dimensions, type: :string, on_delete: :delete_all),
          null: false

      add :activity_type_id,
          references(:dimension_activity_types, type: :string, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create index(:group_activities, [:dimension_id])
    create index(:group_activities, [:activity_type_id])
  end
end
