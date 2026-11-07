defmodule Wiki.Dimension.BlockDimension do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "bdim"}
  @foreign_key_type :string

  schema "block_dimensions" do
    belongs_to :block, Wiki.TextBlock.Block, foreign_key: :block_id
    belongs_to :dimension, Wiki.Dimension.Dimension, foreign_key: :dimension_id

    timestamps(type: :utc_datetime)
  end

  def changeset(block_dimension, attrs) do
    block_dimension
    |> cast(attrs, [:block_id, :dimension_id])
    |> validate_required([:block_id, :dimension_id])
    |> foreign_key_constraint(:block_id)
    |> foreign_key_constraint(:dimension_id)
    |> unique_constraint([:block_id, :dimension_id])
  end
end
