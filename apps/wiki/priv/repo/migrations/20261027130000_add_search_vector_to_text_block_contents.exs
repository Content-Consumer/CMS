defmodule Wiki.Repo.Migrations.AddSearchVectorToTextBlockContents do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE text_block_contents
    ADD COLUMN search_vector tsvector
    GENERATED ALWAYS AS (to_tsvector('english', content)) STORED
    """)

    execute("""
    CREATE INDEX text_block_contents_search_vector_idx
    ON text_block_contents USING gin(search_vector)
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS text_block_contents_search_vector_idx")
    execute("ALTER TABLE text_block_contents DROP COLUMN IF EXISTS search_vector")
  end
end
