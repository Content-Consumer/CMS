defmodule Wiki.Extensions.EnabledExtension do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UXID, autogenerate: true, prefix: "ext"}
  @foreign_key_type :string

  schema "enabled_extensions" do
    field :name, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(enabled_extension, attrs) do
    enabled_extension
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
