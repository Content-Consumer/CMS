defmodule Wiki.SubBlock do
  alias Wiki.Repo
  alias Wiki.SubBlock.SubBlock
  alias Wiki.TextBlock

  def create_subblock(block_id, from_ix, to_ix) do
    case TextBlock.get_block(block_id) do
      nil ->
        {:error, :block_not_found}

      block ->
        content_length = String.length(block.block_content.content)

        %SubBlock{}
        |> SubBlock.changeset(%{block_id: block_id, from_ix: from_ix, to_ix: to_ix}, content_length)
        |> Repo.insert()
    end
  end

  def update_subblock(id, attrs) do
    case Repo.get(SubBlock, id) |> Repo.preload(:block) do
      nil ->
        {:error, :not_found}

      sub_block ->
        block = TextBlock.get_block(sub_block.block_id)
        content_length = String.length(block.block_content.content)

        sub_block
        |> SubBlock.changeset(attrs, content_length)
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
