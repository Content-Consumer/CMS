defmodule Wiki.Block.Extension do
  alias Wiki.Block.Extension.Option

  @callback name() :: String.t()
  @callback block_options(block :: Wiki.TextBlock.Block.t()) :: [Option.t()]
end
