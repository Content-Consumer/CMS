defmodule Wiki.Repo.Migrations.CreateTextBlocks do
  use Ecto.Migration

  def change do
    create table(:text_blocks, primary_key: false) do
      add :id, :string, primary_key: true

      add :content_id,
          references(:text_block_contents, type: :string, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create index(:text_blocks, [:content_id])
  end
end
