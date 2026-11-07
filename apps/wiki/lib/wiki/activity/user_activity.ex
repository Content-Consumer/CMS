defmodule Wiki.Activity.UserActivity do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "uact"}
  @foreign_key_type :string

  schema "user_activities" do
    belongs_to :dimension, Wiki.Dimension.Dimension, foreign_key: :dimension_id
    belongs_to :user, Wiki.Accounts.User, foreign_key: :user_id, type: :integer

    timestamps(type: :utc_datetime)
  end

  def changeset(user_activity, attrs) do
    user_activity
    |> cast(attrs, [:dimension_id, :user_id])
    |> validate_required([:dimension_id, :user_id])
    |> foreign_key_constraint(:dimension_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:dimension_id, :user_id])
  end
end
