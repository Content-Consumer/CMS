defmodule Wiki.Metadata.Field do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "bmf"}
  @foreign_key_type :string

  schema "block_metadata_fields" do
    field :name, :string
    field :label, :string
    field :type, :string

    belongs_to :dimension, Wiki.Dimension.Dimension, foreign_key: :dimension_id

    timestamps(type: :utc_datetime)
  end

  def changeset(field, attrs) do
    field
    |> cast(attrs, [:name, :label, :type, :dimension_id])
    |> validate_required([:name, :label, :type])
    |> foreign_key_constraint(:dimension_id)
    |> unique_constraint([:name, :dimension_id])
  end
end
