defmodule Wiki.Repo.Migrations.CreateBlockVoteReasons do
  use Ecto.Migration

  def change do
    create table(:block_vote_reasons, primary_key: false) do
      add :id, :string, primary_key: true

      add :block_id,
          references(:text_blocks, type: :string, on_delete: :delete_all),
          null: false

      add :voting_activity_id,
          references(:voting_activities, type: :string, on_delete: :delete_all),
          null: false

      add :user_id,
          references(:users, type: :string, on_delete: :nilify_all),
          null: true

      add :reason_block_id,
          references(:text_blocks, type: :string, on_delete: :nilify_all),
          null: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:block_vote_reasons, [:block_id, :voting_activity_id, :user_id])
    create index(:block_vote_reasons, [:voting_activity_id])
    create index(:block_vote_reasons, [:reason_block_id])
  end
end
