defmodule Wiki.Repo.Migrations.CreateSubBlocks do
  use Ecto.Migration

  def change do
    create table(:sub_blocks, primary_key: false) do
      add :id, :string, primary_key: true

      add :block_id,
          references(:text_blocks, type: :string, on_delete: :delete_all),
          null: false

      add :from_ix, :integer, null: false
      add :to_ix, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:sub_blocks, [:block_id])
  end
end
