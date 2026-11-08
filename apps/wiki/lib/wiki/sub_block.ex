defmodule Wiki.SubBlock do
  import Ecto.Query
  alias Wiki.Repo
  alias Wiki.SubBlock.SubBlock

  def create_subblock(block_id, from_ix, to_ix, text \\ nil) do
    version = Wiki.TextBlock.get_current_version(block_id)

    %SubBlock{}
    |> SubBlock.changeset(%{
      block_id: block_id,
      from_ix: from_ix,
      to_ix: to_ix,
      text: text,
      block_content_version_id: version && version.id
    })
    |> Repo.insert()
  end

  def get_subblock(id) do
    Repo.get(SubBlock, id) |> Repo.preload(:block_content_version)
  end

  # Returns %{block_id => [subblocks]} with version preloaded
  def list_subblocks_for_blocks(block_ids) do
    SubBlock
    |> where([s], s.block_id in ^block_ids)
    |> preload(:block_content_version)
    |> Repo.all()
    |> Enum.group_by(& &1.block_id)
  end

  def update_subblock(id, attrs) do
    case Repo.get(SubBlock, id) do
      nil -> {:error, :not_found}
      sub_block ->
        sub_block
        |> SubBlock.changeset(attrs)
        |> Repo.update()
    end
  end

  def remove_subblock(id) do
    case Repo.get(SubBlock, id) do
      nil -> {:error, :not_found}
      sub_block -> Repo.delete(sub_block)
    end
  end
end
