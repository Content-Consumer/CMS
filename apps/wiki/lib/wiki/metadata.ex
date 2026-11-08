defmodule Wiki.Metadata do
  import Ecto.Query
  alias Wiki.Repo
  alias Wiki.Metadata.{Field, Value}
  alias Wiki.Dimension.BlockDimension

  @wiki_defaults [
    %{name: "title", label: "Title", type: "text"},
    %{name: "url", label: "Source URL", type: "text"}
  ]

  @doc """
  Installs wiki default metadata fields idempotently (no dimension_id).
  Safe to call multiple times — skips fields that already exist.
  """
  def install_defaults do
    Enum.each(@wiki_defaults, fn %{name: name} = attrs ->
      existing =
        Field
        |> where([f], f.name == ^name and is_nil(f.dimension_id))
        |> Repo.one()

      unless existing do
        %Field{}
        |> Field.changeset(attrs)
        |> Repo.insert()
      end
    end)
  end

  @doc """
  Installs metadata fields for an extension idempotently.
  Called by Wiki.Extensions.install/1 after dim_map is built.
  Each field in `fields` is a map with keys: name, label, type, dimension_title.
  `dim_map` is a map of dimension_title => %Dimension{}.
  """
  def install_fields(fields, dim_map) do
    Enum.each(fields, fn %{name: name, dimension_title: title} = attrs ->
      dim = Map.fetch!(dim_map, title)

      existing =
        Field
        |> where([f], f.name == ^name and f.dimension_id == ^dim.id)
        |> Repo.one()

      unless existing do
        attrs
        |> Map.delete(:dimension_title)
        |> Map.put(:dimension_id, dim.id)
        |> then(fn a ->
          case Repo.insert(Field.changeset(%Field{}, a)) do
            {:ok, _} -> :ok
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end)
      end
    end)
  end

  def get_field_by_name(name) do
    Field
    |> where([f], f.name == ^name and is_nil(f.dimension_id))
    |> Repo.one()
  end

  def get_field_by_name_in_dimension(name, dimension_id) do
    Field
    |> where([f], f.name == ^name and f.dimension_id == ^dimension_id)
    |> Repo.one()
  end

  # Returns %{block_id => %{field_id => value_map}}.
  # Pass a list of field_ids to filter, or omit for all fields.
  def get_values_for_blocks(block_ids, field_ids \\ :all) do
    base = Value |> where([v], v.block_id in ^block_ids)

    query =
      case field_ids do
        :all -> base
        ids -> where(base, [v], v.field_id in ^ids)
      end

    query
    |> Repo.all()
    |> Enum.group_by(& &1.block_id)
    |> Map.new(fn {block_id, values} ->
      {block_id, Map.new(values, fn v -> {v.field_id, v.value} end)}
    end)
  end

  @doc """
  Returns all metadata fields available for a block:
  - wiki-global fields (dimension_id IS NULL)
  - fields associated with any dimension the block belongs to
  """
  def get_fields_for_block(block_id) do
    dimension_ids =
      BlockDimension
      |> where([bd], bd.block_id == ^block_id)
      |> select([bd], bd.dimension_id)
      |> Repo.all()

    Field
    |> where([f], is_nil(f.dimension_id) or f.dimension_id in ^dimension_ids)
    |> preload(:dimension)
    |> Repo.all()
  end

  @doc """
  Returns all metadata values for a block, with field preloaded.
  """
  def get_values_for_block(block_id) do
    Value
    |> where([v], v.block_id == ^block_id)
    |> preload(:field)
    |> Repo.all()
  end

  @doc """
  Upserts a metadata value for (block_id, field_id).
  Replaces the value if a record already exists for that pair.
  """
  def set_value(block_id, field_id, value) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Value{}
    |> Value.changeset(%{block_id: block_id, field_id: field_id, value: value})
    |> Repo.insert(
      on_conflict: {:replace, [:value, :updated_at]},
      conflict_target: [:block_id, :field_id]
    )
  end

  @doc """
  Casts a vote for user_id on (block_id, field_id).
  The value shape is %{"user_ids" => ["usr_abc", ...]}.
  Idempotent — adding the same user_id twice has no effect.
  """
  def cast_vote(block_id, field_id, user_id) do
    current_value = get_current_value(block_id, field_id)
    user_ids = Map.get(current_value, "user_ids", [])

    unless user_id in user_ids do
      set_value(block_id, field_id, Map.put(current_value, "user_ids", [user_id | user_ids]))
    else
      {:ok, nil}
    end
  end

  @doc """
  Removes a vote for user_id on (block_id, field_id).
  Idempotent — removing a non-existent vote has no effect.
  """
  def remove_vote(block_id, field_id, user_id) do
    current_value = get_current_value(block_id, field_id)
    user_ids = Map.get(current_value, "user_ids", [])
    new_user_ids = List.delete(user_ids, user_id)
    set_value(block_id, field_id, Map.put(current_value, "user_ids", new_user_ids))
  end

  @doc """
  Returns true if `user_id` is in the value's user_ids list.
  """
  def has_voted?(value, user_id) when is_map(value) do
    user_id in Map.get(value, "user_ids", [])
  end

  @doc """
  Returns the number of votes in the value's user_ids list.
  """
  def vote_count(value) when is_map(value) do
    Map.get(value, "user_ids", []) |> length()
  end

  def voter_ids(value) when is_map(value), do: Map.get(value, "user_ids", [])
  def voter_ids(_), do: []

  # Fetches the current raw value map for (block_id, field_id), or returns an
  # empty map if no record exists yet.
  defp get_current_value(block_id, field_id) do
    case Repo.get_by(Value, block_id: block_id, field_id: field_id) do
      %Value{value: v} -> v
      nil -> %{}
    end
  end
end
