defmodule Wiki.TextBlock.BlockContent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "blkc"}
  @foreign_key_type :string

  schema "text_block_contents" do
    field :content, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(block_content, attrs) do
    block_content
    |> cast(attrs, [:content])
    |> validate_required([:content])
  end
end
