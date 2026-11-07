defmodule Wiki.Activity.GroupActivity do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "gact"}
  @foreign_key_type :string

  schema "group_activities" do
    belongs_to :dimension, Wiki.Dimension.Dimension, foreign_key: :dimension_id
    belongs_to :activity_type, Wiki.Activity.DimensionActivityType, foreign_key: :activity_type_id

    field :name, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(group_activity, attrs) do
    group_activity
    |> cast(attrs, [:dimension_id, :activity_type_id, :name])
    |> validate_required([:dimension_id, :activity_type_id, :name])
    |> foreign_key_constraint(:dimension_id)
    |> foreign_key_constraint(:activity_type_id)
  end
end
