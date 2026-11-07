defmodule Wiki.BlockRelationship do
  import Ecto.Query
  alias Wiki.Repo
  alias Wiki.BlockRelationship.{Type, Relation}

  @wiki_defaults [
    %{name: "references", label: "References", directional: true}
  ]

  def install_defaults do
    Enum.each(@wiki_defaults, fn %{name: name} = attrs ->
      existing = Type |> where([t], t.name == ^name and is_nil(t.dimension_id)) |> Repo.one()
      unless existing do
        %Type{} |> Type.changeset(attrs) |> Repo.insert()
      end
    end)
  end

  def install_types(types, dim_map) do
    Enum.each(types, fn %{name: name, dimension_title: title} = attrs ->
      dim = Map.fetch!(dim_map, title)
      existing = Type |> where([t], t.name == ^name and t.dimension_id == ^dim.id) |> Repo.one()
      unless existing do
        attrs
        |> Map.delete(:dimension_title)
        |> Map.put(:dimension_id, dim.id)
        |> then(fn a ->
          case Repo.insert(Type.changeset(%Type{}, a)) do
            {:ok, _} -> :ok
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end)
      end
    end)
  end

  def get_type_by_name(name) do
    Type |> where([t], t.name == ^name and is_nil(t.dimension_id)) |> Repo.one()
  end

  def get_type_by_name_in_dimension(name, dimension_id) do
    Type |> where([t], t.name == ^name and t.dimension_id == ^dimension_id) |> Repo.one()
  end

  def list_types_for_dimension(dimension_id) do
    Type |> where([t], t.dimension_id == ^dimension_id) |> Repo.all()
  end

  def create_relation(source_block_id, target_block_id, type_id) do
    %Relation{}
    |> Relation.changeset(%{source_block_id: source_block_id, target_block_id: target_block_id, type_id: type_id})
    |> Repo.insert()
  end

  def delete_relation(id) do
    case Repo.get(Relation, id) do
      nil -> {:error, :not_found}
      rel -> Repo.delete(rel)
    end
  end

  # Returns all relations where block_id is source or target, with type and both blocks (with block_content) preloaded
  def list_relations_for_block(block_id) do
    Relation
    |> where([r], r.source_block_id == ^block_id or r.target_block_id == ^block_id)
    |> preload([:type, source_block: :block_content, target_block: :block_content])
    |> Repo.all()
  end

  # Returns relations for block_id filtered by type name (wiki-global type)
  def list_relations_by_type_name(block_id, type_name) do
    Relation
    |> join(:inner, [r], t in Type, on: r.type_id == t.id and t.name == ^type_name and is_nil(t.dimension_id))
    |> where([r], r.source_block_id == ^block_id or r.target_block_id == ^block_id)
    |> preload([:type, source_block: :block_content, target_block: :block_content])
    |> Repo.all()
  end

  # Returns relations for block_id filtered by type name in a dimension
  def list_relations_by_type_name_in_dimension(block_id, type_name, dimension_id) do
    Relation
    |> join(:inner, [r], t in Type, on: r.type_id == t.id and t.name == ^type_name and t.dimension_id == ^dimension_id)
    |> where([r], r.source_block_id == ^block_id or r.target_block_id == ^block_id)
    |> preload([:type, source_block: :block_content, target_block: :block_content])
    |> Repo.all()
  end

  # Returns a map of block_id => [relations] for a list of block_ids (preloads type + both blocks)
  def list_relations_for_blocks(block_ids) do
    block_id_set = MapSet.new(block_ids)

    Relation
    |> where([r], r.source_block_id in ^block_ids or r.target_block_id in ^block_ids)
    |> preload([:type, source_block: :block_content, target_block: :block_content])
    |> Repo.all()
    |> Enum.flat_map(fn rel ->
      entries = []
      entries = if MapSet.member?(block_id_set, rel.source_block_id), do: [{rel.source_block_id, rel} | entries], else: entries
      entries = if MapSet.member?(block_id_set, rel.target_block_id) and rel.target_block_id != rel.source_block_id, do: [{rel.target_block_id, rel} | entries], else: entries
      entries
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end
end
