defmodule Mix.Tasks.Wiki.Migrate do
  use Mix.Task

  @shortdoc "Runs all migrations: wiki core + extension-owned"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.config", args)

    repo = Wiki.Repo
    app_dir = :code.priv_dir(:wiki) |> to_string()
    wiki_migrations = Path.join(app_dir, "repo/migrations")

    umbrella_root = Path.expand("../../../..", app_dir)
    deliberation_migrations = Path.join(umbrella_root, "apps/deliberation/priv/repo/migrations")

    paths =
      [wiki_migrations, deliberation_migrations]
      |> Enum.filter(&File.dir?/1)

    {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn repo ->
      Ecto.Migrator.run(repo, paths, :up, all: true)
    end)
  end
end
