defmodule Wiki.Metadata.Value do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "bmv"}
  @foreign_key_type :string

  schema "block_metadata_values" do
    belongs_to :block, Wiki.TextBlock.Block, foreign_key: :block_id
    belongs_to :field, Wiki.Metadata.Field, foreign_key: :field_id

    field :value, :map

    timestamps(type: :utc_datetime)
  end

  def changeset(value, attrs) do
    value
    |> cast(attrs, [:block_id, :field_id, :value])
    |> validate_required([:block_id, :field_id, :value])
    |> foreign_key_constraint(:block_id)
    |> foreign_key_constraint(:field_id)
    |> unique_constraint([:block_id, :field_id])
  end
end
