defmodule Wiki.Dimension do
  alias Wiki.Repo
  alias Wiki.Dimension.{Dimension, BlockDimension}

  def create_dimension(attrs) do
    %Dimension{}
    |> Dimension.changeset(attrs)
    |> Repo.insert()
  end

  def update_dimension(id, attrs) do
    case Repo.get(Dimension, id) do
      nil -> {:error, :not_found}
      dimension -> dimension |> Dimension.changeset(attrs) |> Repo.update()
    end
  end

  def delete_dimension(id) do
    case Repo.get(Dimension, id) do
      nil -> {:error, :not_found}
      dimension -> Repo.delete(dimension)
    end
  end

  def add_block_to_dimension(block_id, dimension_id) do
    %BlockDimension{}
    |> BlockDimension.changeset(%{block_id: block_id, dimension_id: dimension_id})
    |> Repo.insert()
  end

  def remove_block_from_dimension(block_id, dimension_id) do
    case Repo.get_by(BlockDimension, block_id: block_id, dimension_id: dimension_id) do
      nil -> {:error, :not_found}
      block_dimension -> Repo.delete(block_dimension)
    end
  end
end
