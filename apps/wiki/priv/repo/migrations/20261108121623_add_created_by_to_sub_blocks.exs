defmodule Wiki.Repo.Migrations.AddCreatedByToSubBlocks do
  use Ecto.Migration

  def change do
    alter table(:sub_blocks) do
      add :created_by_id, references(:users, type: :string, on_delete: :nilify_all), null: true
    end

    create index(:sub_blocks, [:created_by_id])
  end
end
