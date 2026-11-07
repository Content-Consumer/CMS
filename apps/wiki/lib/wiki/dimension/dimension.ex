defmodule Wiki.Dimension.Dimension do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "dim"}
  @foreign_key_type :string

  schema "dimensions" do
    field :title, :string
    field :description, :string

    has_many :block_dimensions, Wiki.Dimension.BlockDimension

    timestamps(type: :utc_datetime)
  end

  def changeset(dimension, attrs) do
    dimension
    |> cast(attrs, [:title, :description])
    |> validate_required([:title])
  end
end
