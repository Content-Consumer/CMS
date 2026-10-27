defmodule Deliberation.BlockParams do
  @enforce_keys [:block_id]
  defstruct [:block_id]

  @type t :: %__MODULE__{
    block_id: String.t()
  }
end
