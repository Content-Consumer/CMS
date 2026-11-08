defmodule Wiki.Repo.Migrations.AddCreatedByToBlockKinds do
  use Ecto.Migration

  def change do
    alter table(:deliberation_block_kinds) do
      add :created_by_id, references(:users, type: :string, on_delete: :nilify_all), null: true
    end

    create index(:deliberation_block_kinds, [:created_by_id])
  end
end
