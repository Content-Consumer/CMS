defmodule Wiki.Repo.Migrations.CreateVotingActivityLinks do
  use Ecto.Migration

  def change do
    create table(:voting_activity_links, primary_key: false) do
      add :id, :string, primary_key: true

      add :voting_activity_id,
          references(:voting_activities, type: :string, on_delete: :delete_all),
          null: false

      add :argument_activity_id,
          references(:group_activities, type: :string, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:voting_activity_links, [:voting_activity_id, :argument_activity_id])
    create index(:voting_activity_links, [:argument_activity_id])
  end
end
