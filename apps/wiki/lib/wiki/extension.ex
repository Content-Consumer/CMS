defmodule Wiki.Extension do
  @type dimension_blueprint :: %{title: String.t(), description: String.t() | nil}
  @type activity_type_blueprint :: %{
          dimension_title: String.t(),
          name: String.t(),
          type: String.t()
        }

  @callback name() :: String.t()
  @callback dimensions() :: [dimension_blueprint()]
  @callback activity_types() :: [activity_type_blueprint()]
end
