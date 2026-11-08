defmodule Deliberation.BlockVoteReason do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "dvr"}
  @foreign_key_type :string

  schema "block_vote_reasons" do
    belongs_to :block, Wiki.TextBlock.Block, foreign_key: :block_id
    belongs_to :voting_activity, Deliberation.VotingActivity, foreign_key: :voting_activity_id
    belongs_to :user, Wiki.Accounts.User, foreign_key: :user_id, type: :string
    belongs_to :reason_block, Wiki.TextBlock.Block, foreign_key: :reason_block_id

    timestamps(type: :utc_datetime)
  end

  def changeset(reason, attrs) do
    reason
    |> cast(attrs, [:block_id, :voting_activity_id, :user_id, :reason_block_id])
    |> validate_required([:block_id, :voting_activity_id, :user_id])
    |> unique_constraint([:block_id, :voting_activity_id, :user_id])
    |> foreign_key_constraint(:block_id)
    |> foreign_key_constraint(:voting_activity_id)
    |> foreign_key_constraint(:reason_block_id)
  end
end
