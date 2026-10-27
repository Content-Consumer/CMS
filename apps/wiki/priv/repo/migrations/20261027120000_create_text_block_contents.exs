defmodule Wiki.Repo.Migrations.CreateTextBlockContents do
  use Ecto.Migration

  def change do
    create table(:text_block_contents, primary_key: false) do
      add :id, :string, primary_key: true
      add :content, :text, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
