defmodule Deliberation.VotingActivityLink do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "dvl"}
  @foreign_key_type :string

  schema "voting_activity_links" do
    belongs_to :voting_activity, Deliberation.VotingActivity, foreign_key: :voting_activity_id
    belongs_to :argument_activity, Wiki.Activity.GroupActivity, foreign_key: :argument_activity_id

    timestamps(type: :utc_datetime)
  end

  def changeset(link, attrs) do
    link
    |> cast(attrs, [:voting_activity_id, :argument_activity_id])
    |> validate_required([:voting_activity_id, :argument_activity_id])
    |> unique_constraint([:voting_activity_id, :argument_activity_id])
    |> foreign_key_constraint(:voting_activity_id)
    |> foreign_key_constraint(:argument_activity_id)
  end
end
