defmodule Wiki.SubBlock.SubBlock do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "sblk"}
  @foreign_key_type :string

  schema "sub_blocks" do
    belongs_to :block, Wiki.TextBlock.Block, foreign_key: :block_id
    belongs_to :block_content_version, Wiki.TextBlock.BlockContentVersion
    belongs_to :created_by, Wiki.Accounts.User, foreign_key: :created_by_id, type: :string

    field :from_ix, :integer
    field :to_ix, :integer
    field :text, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(sub_block, attrs, _content_length \\ nil) do
    sub_block
    |> cast(attrs, [:block_id, :block_content_version_id, :from_ix, :to_ix, :text, :created_by_id])
    |> validate_required([:block_id, :from_ix, :to_ix])
    |> validate_number(:from_ix, greater_than_or_equal_to: 0)
    |> validate_from_before_to()
    |> foreign_key_constraint(:block_id)
    |> foreign_key_constraint(:block_content_version_id)
  end

  defp validate_from_before_to(changeset) do
    from_ix = get_field(changeset, :from_ix)
    to_ix = get_field(changeset, :to_ix)

    if from_ix && to_ix && from_ix >= to_ix do
      add_error(changeset, :from_ix, "must be less than to_ix")
    else
      changeset
    end
  end
end
