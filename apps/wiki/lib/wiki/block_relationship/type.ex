defmodule Wiki.BlockRelationship.Type do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "brt"}
  @foreign_key_type :string
  schema "block_relationship_types" do
    field :name, :string
    field :label, :string
    field :directional, :boolean, default: true
    belongs_to :dimension, Wiki.Dimension
    timestamps()
  end

  def changeset(type, attrs) do
    type
    |> cast(attrs, [:name, :label, :directional, :dimension_id])
    |> validate_required([:name, :label, :directional])
  end
end
