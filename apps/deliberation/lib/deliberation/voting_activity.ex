defmodule Deliberation.VotingActivity do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "dva"}
  @foreign_key_type :string

  schema "voting_activities" do
    belongs_to :group_activity, Wiki.Activity.GroupActivity, foreign_key: :group_activity_id
    has_many :links, Deliberation.VotingActivityLink, foreign_key: :voting_activity_id

    field :objective, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(voting_activity, attrs) do
    voting_activity
    |> cast(attrs, [:group_activity_id, :objective])
    |> validate_required([:group_activity_id])
    |> unique_constraint(:group_activity_id)
    |> foreign_key_constraint(:group_activity_id)
  end
end
