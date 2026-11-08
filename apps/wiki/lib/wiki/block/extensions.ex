defmodule Wiki.Block.Extensions do
  alias Wiki.Block.Extension

  @spec registered() :: [module()]
  def registered do
    Application.get_env(:wiki, :extensions, [])
  end

  @spec options_for(block :: Wiki.TextBlock.Block.t()) :: [{String.t(), [Extension.Option.t()]}]
  def options_for(block) do
    registered()
    |> Enum.map(fn mod -> {mod.name(), mod.block_options(block)} end)
    |> Enum.reject(fn {_, opts} -> opts == [] end)
  end

  @spec detail_sections_for(block :: Wiki.TextBlock.Block.t()) :: [map()]
  def detail_sections_for(block) do
    registered()
    |> Enum.filter(fn mod -> function_exported?(mod, :block_detail_sections, 1) end)
    |> Enum.flat_map(fn mod -> mod.block_detail_sections(block) end)
    |> Enum.reject(fn section -> section.items == [] end)
  end
end
