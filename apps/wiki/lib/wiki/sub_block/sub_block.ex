defmodule Wiki.SubBlock.SubBlock do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "sblk"}
  @foreign_key_type :string

  schema "sub_blocks" do
    belongs_to :block, Wiki.TextBlock.Block, foreign_key: :block_id

    field :from_ix, :integer
    field :to_ix, :integer

    timestamps(type: :utc_datetime)
  end

  def changeset(sub_block, attrs, content_length) do
    sub_block
    |> cast(attrs, [:block_id, :from_ix, :to_ix])
    |> validate_required([:block_id, :from_ix, :to_ix])
    |> validate_number(:from_ix, greater_than_or_equal_to: 0)
    |> validate_number(:to_ix, greater_than: 0, less_than: content_length)
    |> validate_from_before_to()
    |> foreign_key_constraint(:block_id)
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
