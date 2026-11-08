defmodule Wiki.Repo.Migrations.WidenSubBlockText do
  use Ecto.Migration

  def change do
    alter table(:sub_blocks) do
      modify :text, :text, null: true, from: {:string, null: true}
    end
  end
end
