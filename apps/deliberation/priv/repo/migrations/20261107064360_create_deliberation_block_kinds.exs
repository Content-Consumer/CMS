defmodule Wiki.Repo.Migrations.CreateDeliberationBlockKinds do
  use Ecto.Migration

  def change do
    create table(:deliberation_block_kinds, primary_key: false) do
      add :id, :string, primary_key: true

      add :block_id,
          references(:text_blocks, type: :string, on_delete: :delete_all),
          null: false

      add :group_activity_id,
          references(:group_activities, type: :string, on_delete: :delete_all),
          null: false

      add :kind, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:deliberation_block_kinds, [:block_id])
    create index(:deliberation_block_kinds, [:group_activity_id])
  end
end
