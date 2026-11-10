defmodule Wiki.TextBlock do
  import Ecto.Query
  alias Wiki.Repo
  alias Wiki.TextBlock.{Block, BlockContent, BlockContentVersion}

  def create_block(markdown, user_id \\ nil) do
    Repo.transaction(fn ->
      with {:ok, content} <-
             Repo.insert(BlockContent.changeset(%BlockContent{}, %{content: markdown})),
           {:ok, block} <-
             Repo.insert(Block.changeset(%Block{}, %{content_id: content.id, created_by_id: user_id})),
           {:ok, _version} <-
             Repo.insert(BlockContentVersion.changeset(%BlockContentVersion{}, %{
               block_id: block.id,
               content: markdown,
               version_num: 1
             })) do
        %{block | block_content: content}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def get_block(id) do
    Block
    |> Repo.get(id)
    |> Repo.preload([:block_content, :created_by])
  end

  def get_all_blocks do
    Block
    |> order_by([b], desc: b.inserted_at)
    |> Repo.all()
    |> Repo.preload(:block_content)
  end

  def update_block(id, markdown) do
    case get_block(id) do
      nil ->
        {:error, :not_found}

      block ->
        Repo.transaction(fn ->
          with {:ok, updated_content} <-
                 Repo.update(BlockContent.changeset(block.block_content, %{content: markdown})),
               next_num <- next_version_num(id),
               {:ok, _version} <-
                 Repo.insert(BlockContentVersion.changeset(%BlockContentVersion{}, %{
                   block_id: id,
                   content: markdown,
                   version_num: next_num
                 })) do
            {:ok, %{block | block_content: updated_content}}
          else
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end)
        |> case do
          {:ok, {:ok, block}} -> {:ok, block}
          {:error, _} = err -> err
        end
    end
  end

  defp next_version_num(block_id) do
    max_num =
      Repo.one(
        from v in BlockContentVersion,
          where: v.block_id == ^block_id,
          select: max(v.version_num)
      ) || 0

    max_num + 1
  end

  def get_current_version(block_id) do
    BlockContentVersion
    |> where([v], v.block_id == ^block_id)
    |> order_by([v], desc: v.version_num)
    |> limit(1)
    |> Repo.one()
  end

  def search_blocks(query) when is_binary(query) and query != "" do
    Block
    |> join(:inner, [b], bc in BlockContent, on: b.content_id == bc.id)
    |> where([_, bc], fragment("? @@ plainto_tsquery('english', ?)", bc.search_vector, ^query))
    |> order_by([_, bc], desc: fragment("ts_rank(?, plainto_tsquery('english', ?))", bc.search_vector, ^query))
    |> preload(:block_content)
    |> Repo.all()
  end

  def search_blocks(_), do: get_all_blocks()

  def delete_block(id) do
    case Repo.get(Block, id) |> Repo.preload(:block_content) do
      nil -> {:error, :not_found}
      %Block{block_content: content} -> Repo.delete(content)
    end
  end
end
