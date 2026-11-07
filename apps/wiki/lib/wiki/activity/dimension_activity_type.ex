defmodule Wiki.Activity.DimensionActivityType do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "dimat"}
  @foreign_key_type :string

  schema "dimension_activity_types" do
    belongs_to :dimension, Wiki.Dimension.Dimension, foreign_key: :dimension_id

    field :name, :string
    field :type, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(activity_type, attrs) do
    activity_type
    |> cast(attrs, [:dimension_id, :name, :type])
    |> validate_required([:dimension_id, :name, :type])
    |> foreign_key_constraint(:dimension_id)
    |> unique_constraint([:dimension_id, :type, :name])
  end
end
