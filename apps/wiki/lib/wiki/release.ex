defmodule Wiki.Release do
  @moduledoc """
  Run database migrations from a Mix-free production release.

  Usage:
    bin/cms eval "Wiki.Release.migrate()"
  """

  @app :wiki

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          Ecto.Migrator.run(repo, migration_paths(), :up, all: true)
        end)
    end
  end

  defp migration_paths do
    [:wiki, :deliberation]
    |> Enum.map(fn app -> :code.priv_dir(app) |> to_string() |> Path.join("repo/migrations") end)
    |> Enum.filter(&File.dir?/1)
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
