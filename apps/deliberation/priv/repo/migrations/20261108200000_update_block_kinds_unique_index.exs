defmodule Deliberation.Repo.Migrations.UpdateBlockKindsUniqueIndex do
  use Ecto.Migration

  def change do
    drop unique_index(:deliberation_block_kinds, [:block_id])
    create unique_index(:deliberation_block_kinds, [:block_id, :group_activity_id, :kind])
  end
end
