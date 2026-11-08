defmodule Wiki.TextBlock.BlockContentVersion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "bcv"}
  @foreign_key_type :string

  schema "block_content_versions" do
    belongs_to :block, Wiki.TextBlock.Block
    field :content, :string
    field :version_num, :integer
    timestamps(updated_at: false)
  end

  def changeset(version, attrs) do
    version
    |> cast(attrs, [:block_id, :content, :version_num])
    |> validate_required([:block_id, :content, :version_num])
  end
end
