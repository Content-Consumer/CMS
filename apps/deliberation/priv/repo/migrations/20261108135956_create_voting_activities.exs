defmodule Wiki.Repo.Migrations.CreateVotingActivities do
  use Ecto.Migration

  def change do
    create table(:voting_activities, primary_key: false) do
      add :id, :string, primary_key: true

      add :group_activity_id,
          references(:group_activities, type: :string, on_delete: :delete_all),
          null: false

      add :objective, :text, null: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:voting_activities, [:group_activity_id])
  end
end
