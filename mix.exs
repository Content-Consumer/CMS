defmodule Cms.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    []
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create --repo Wiki.Repo", "wiki.migrate"],
      "ecto.reset": ["ecto.drop --repo Wiki.Repo", "ecto.setup"],
      "assets.setup": ["cmd --cd apps/wiki mix assets.setup"],
      "assets.build": ["cmd --cd apps/wiki mix assets.build"]
    ]
  end
end
