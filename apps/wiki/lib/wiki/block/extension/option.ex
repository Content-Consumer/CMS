defmodule Wiki.Block.Extension.Option do
  @enforce_keys [:label, :event, :block_id, :params]
  defstruct [:label, :icon, :event, :block_id, :params]

  @type t :: %__MODULE__{
    label: String.t(),
    icon: String.t() | nil,
    event: String.t(),
    block_id: String.t(),
    params: struct()
  }
end
