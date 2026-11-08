defmodule Mix.Tasks.Wiki.Migrate do
  use Mix.Task

  @shortdoc "Runs all migrations across every app in the umbrella"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.config", args)

    paths =
      Mix.Project.apps_paths()
      |> Map.values()
      |> Enum.map(&Path.join(&1, "priv/repo/migrations"))
      |> Enum.filter(&File.dir?/1)

    {:ok, _, _} = Ecto.Migrator.with_repo(Wiki.Repo, fn repo ->
      Ecto.Migrator.run(repo, paths, :up, all: true)
    end)
  end
end
