defmodule Deliberation.BlockKind do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "dbk"}
  @foreign_key_type :string

  schema "deliberation_block_kinds" do
    belongs_to :block, Wiki.TextBlock.Block, foreign_key: :block_id
    belongs_to :group_activity, Wiki.Activity.GroupActivity, foreign_key: :group_activity_id
    belongs_to :created_by, Wiki.Accounts.User, foreign_key: :created_by_id, type: :string

    field :kind, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(block_kind, attrs) do
    block_kind
    |> cast(attrs, [:block_id, :group_activity_id, :kind, :created_by_id])
    |> validate_required([:block_id, :group_activity_id, :kind])
    |> validate_inclusion(:kind, ["argument", "statement", "poll_item", "source"])
    |> unique_constraint([:block_id, :group_activity_id, :kind],
      name: :deliberation_block_kinds_block_id_group_activity_id_kind_index
    )
    |> foreign_key_constraint(:block_id)
    |> foreign_key_constraint(:group_activity_id)
  end
end
