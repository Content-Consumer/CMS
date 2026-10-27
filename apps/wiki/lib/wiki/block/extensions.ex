defmodule Wiki.Block.Extensions do
  alias Wiki.Block.Extension

  @spec registered() :: [module()]
  def registered do
    Application.get_env(:wiki, :block_extensions, [])
  end

  @spec options_for(block :: Wiki.TextBlock.Block.t()) :: [{String.t(), [Extension.Option.t()]}]
  def options_for(block) do
    registered()
    |> Enum.map(fn mod -> {mod.name(), mod.block_options(block)} end)
    |> Enum.reject(fn {_, opts} -> opts == [] end)
  end
end
