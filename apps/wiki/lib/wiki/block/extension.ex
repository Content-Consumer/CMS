defmodule Wiki.Block.Extension do
  alias Wiki.Block.Extension.Option

  @callback name() :: String.t()
  @callback block_options(block :: Wiki.TextBlock.Block.t()) :: [Option.t()]

  @optional_callbacks [home_path: 0, block_detail_sections: 1]
  @callback home_path() :: String.t()

  @callback block_detail_sections(block :: Wiki.TextBlock.Block.t()) ::
              [%{title: String.t(), items: [%{label: String.t(), href: String.t(), badge: String.t() | nil}]}]
end
