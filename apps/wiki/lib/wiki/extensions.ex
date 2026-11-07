defmodule Wiki.Extensions do
  require Logger

  alias Wiki.Repo
  alias Wiki.Extensions.EnabledExtension
  alias Wiki.Dimension
  alias Wiki.Activity

  def registered do
    Application.get_env(:wiki, :extensions, [])
  end

  def enable_all do
    registered()
    |> Enum.filter(&function_exported?(&1, :dimensions, 0))
    |> Enum.each(&enable/1)
  end

  def enable(module) do
    name = module.name()

    case Repo.get_by(EnabledExtension, name: name) do
      %EnabledExtension{} ->
        Logger.info("Extension #{name} already enabled, skipping")
        :ok

      nil ->
        install(module)
    end
  end

  defp install(module) do
    name = module.name()
    Logger.info("Enabling extension: #{name}")

    Repo.transaction(fn ->
      dim_map =
        module.dimensions()
        |> Enum.reduce(%{}, fn attrs, acc ->
          case Dimension.create_dimension(attrs) do
            {:ok, dim} -> Map.put(acc, attrs.title, dim)
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end)

      module.activity_types()
      |> Enum.each(fn %{dimension_title: title} = attrs ->
        dim = Map.fetch!(dim_map, title)

        attrs
        |> Map.delete(:dimension_title)
        |> Map.put(:dimension_id, dim.id)
        |> then(fn a ->
          case Activity.create_activity_type(a) do
            {:ok, _} -> :ok
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end)
      end)

      case Repo.insert(EnabledExtension.changeset(%EnabledExtension{}, %{name: name})) do
        {:ok, _} -> :ok
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end
end
