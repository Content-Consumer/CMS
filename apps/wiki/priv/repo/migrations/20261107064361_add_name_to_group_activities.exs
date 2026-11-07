defmodule Wiki.Repo.Migrations.AddNameToGroupActivities do
  use Ecto.Migration

  def change do
    alter table(:group_activities) do
      add :name, :string, null: false, default: ""
    end
  end
end
