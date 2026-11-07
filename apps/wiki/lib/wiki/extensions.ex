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
    all = registered()
    Logger.info("[Extensions] enable_all: registered=#{inspect(all)}")

    filtered = Enum.filter(all, fn mod ->
      Code.ensure_loaded?(mod) && function_exported?(mod, :dimensions, 0)
    end)
    Logger.info("[Extensions] enable_all: filtered=#{inspect(filtered)}")

    filtered
    |> Enum.each(fn mod ->
      try do
        case enable(mod) do
          :ok -> Logger.info("Extension #{mod.name()} enabled successfully")
          {:error, reason} ->
            Logger.warning("Failed to enable extension #{mod.name()}: #{inspect(reason)}")
        end
      rescue
        e -> Logger.warning("Failed to enable extension #{mod.name()} (exception): #{inspect(e)}")
      end
    end)
  end

  def enable(module) do
    name = module.name()

    case Repo.get_by(EnabledExtension, name: name) do
      %EnabledExtension{} ->
        Logger.info("Extension #{name} already enabled, syncing")
        sync_extension(module)

      nil ->
        install(module)
    end
  end

  defp sync_extension(module) do
    dim_map =
      module.dimensions()
      |> Enum.reduce(%{}, fn %{title: title}, acc ->
        case Wiki.Dimension.get_dimension_by_title(title) do
          nil -> acc
          dim -> Map.put(acc, title, dim)
        end
      end)

    if function_exported?(module, :metadata_fields, 0) do
      Wiki.Metadata.install_fields(module.metadata_fields(), dim_map)
    end

    if function_exported?(module, :relationship_types, 0) do
      Wiki.BlockRelationship.install_types(module.relationship_types(), dim_map)
    end

    :ok
  end

  defp install(module) do
    name = module.name()
    Logger.info("Enabling extension: #{name}")

    case Repo.transaction(fn ->
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

      if function_exported?(module, :metadata_fields, 0) do
        case Wiki.Metadata.install_fields(module.metadata_fields(), dim_map) do
          :ok -> :ok
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end

      if function_exported?(module, :relationship_types, 0) do
        case Wiki.BlockRelationship.install_types(module.relationship_types(), dim_map) do
          :ok -> :ok
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end

      case Repo.insert(EnabledExtension.changeset(%EnabledExtension{}, %{name: name})) do
        {:ok, _} -> :ok
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end) do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end
end
