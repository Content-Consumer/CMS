defmodule Deliberation do
  @behaviour Wiki.Block.Extension

  alias Wiki.Block.Extension.Option
  alias Deliberation.BlockParams

  @impl Wiki.Block.Extension
  def name, do: "Deliberation"

  @impl Wiki.Block.Extension
  def block_options(block) do
    [
      %Option{
        label: "Start deliberation",
        icon: "hero-chat-bubble-left-right",
        event: "deliberation_start",
        block_id: block.id,
        params: %BlockParams{block_id: block.id}
      },
      %Option{
        label: "View deliberations",
        icon: "hero-list-bullet",
        event: "deliberation_view",
        block_id: block.id,
        params: %BlockParams{block_id: block.id}
      }
    ]
  end
end
