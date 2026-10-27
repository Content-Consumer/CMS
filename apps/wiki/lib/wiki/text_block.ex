defmodule Wiki.TextBlock do
  import Ecto.Query
  alias Wiki.Repo
  alias Wiki.TextBlock.{Block, BlockContent}

  def create_block(markdown) do
    Repo.transaction(fn ->
      with {:ok, content} <-
             Repo.insert(BlockContent.changeset(%BlockContent{}, %{content: markdown})),
           {:ok, block} <-
             Repo.insert(Block.changeset(%Block{}, %{content_id: content.id})) do
        %{block | block_content: content}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def get_block(id) do
    Block
    |> Repo.get(id)
    |> Repo.preload(:block_content)
  end

  def get_all_blocks do
    Block
    |> Repo.all()
    |> Repo.preload(:block_content)
  end

  def update_block(id, markdown) do
    case get_block(id) do
      nil ->
        {:error, :not_found}

      block ->
        with {:ok, updated_content} <-
               Repo.update(BlockContent.changeset(block.block_content, %{content: markdown})) do
          {:ok, %{block | block_content: updated_content}}
        end
    end
  end

  def delete_block(id) do
    case Repo.get(Block, id) |> Repo.preload(:block_content) do
      nil -> {:error, :not_found}
      %Block{block_content: content} -> Repo.delete(content)
    end
  end
end
