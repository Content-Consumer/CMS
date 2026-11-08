defmodule Wiki.Repo.Migrations.AddCreatedByToBlocks do
  use Ecto.Migration

  def change do
    alter table(:text_blocks) do
      add :created_by_id, references(:users, type: :string, on_delete: :nilify_all), null: true
    end

    create index(:text_blocks, [:created_by_id])
  end
end
