defmodule Wiki.Extension do
  @type dimension_blueprint :: %{title: String.t(), description: String.t() | nil}
  @type activity_type_blueprint :: %{
          dimension_title: String.t(),
          name: String.t(),
          type: String.t()
        }
  @type metadata_field_blueprint :: %{
          name: String.t(),
          label: String.t(),
          type: String.t(),
          dimension_title: String.t()
        }

  @callback name() :: String.t()
  @callback dimensions() :: [dimension_blueprint()]
  @callback activity_types() :: [activity_type_blueprint()]

  @type relationship_type_blueprint :: %{
          name: String.t(),
          label: String.t(),
          directional: boolean(),
          dimension_title: String.t()
        }

  @optional_callbacks [metadata_fields: 0, relationship_types: 0]
  @callback metadata_fields() :: [metadata_field_blueprint()]
  @callback relationship_types() :: [relationship_type_blueprint()]
end
