defmodule Wiki.BlockRelationship.Relation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "brel"}
  @foreign_key_type :string
  schema "block_relationships" do
    belongs_to :source_block, Wiki.TextBlock.Block, foreign_key: :source_block_id
    belongs_to :target_block, Wiki.TextBlock.Block, foreign_key: :target_block_id
    belongs_to :type, Wiki.BlockRelationship.Type
    timestamps()
  end

  def changeset(rel, attrs) do
    rel
    |> cast(attrs, [:source_block_id, :target_block_id, :type_id])
    |> validate_required([:source_block_id, :target_block_id, :type_id])
    |> unique_constraint([:source_block_id, :target_block_id, :type_id])
  end
end
