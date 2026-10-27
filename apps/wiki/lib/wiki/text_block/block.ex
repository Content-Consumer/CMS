defmodule Wiki.TextBlock.Block do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "blk"}
  @foreign_key_type :string

  schema "text_blocks" do
    belongs_to :block_content, Wiki.TextBlock.BlockContent, foreign_key: :content_id

    timestamps(type: :utc_datetime)
  end

  def changeset(block, attrs) do
    block
    |> cast(attrs, [:content_id])
    |> validate_required([:content_id])
  end
end
