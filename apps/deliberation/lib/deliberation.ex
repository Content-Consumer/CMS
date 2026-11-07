defmodule Deliberation do
  @behaviour Wiki.Block.Extension
  @behaviour Wiki.Extension

  alias Wiki.Block.Extension.Option
  alias Deliberation.BlockParams

  @impl Wiki.Extension
  def dimensions do
    [
      %{title: "Deliberation", description: "A space for structured group deliberation"}
    ]
  end

  @impl Wiki.Extension
  def activity_types do
    [
      %{dimension_title: "Deliberation", name: "Open Discussion", type: "deliberation"},
      %{dimension_title: "Deliberation", name: "Voting", type: "deliberation_voting"}
    ]
  end

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
