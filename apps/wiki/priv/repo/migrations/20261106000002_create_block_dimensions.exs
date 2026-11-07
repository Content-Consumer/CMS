defmodule Wiki.Repo.Migrations.CreateBlockDimensions do
  use Ecto.Migration

  def change do
    create table(:block_dimensions, primary_key: false) do
      add :id, :string, primary_key: true

      add :block_id,
          references(:text_blocks, type: :string, on_delete: :delete_all),
          null: false

      add :dimension_id,
          references(:dimensions, type: :string, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create index(:block_dimensions, [:block_id])
    create index(:block_dimensions, [:dimension_id])
    create unique_index(:block_dimensions, [:block_id, :dimension_id])
  end
end
