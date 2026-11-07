defmodule Wiki.Extension.Web do
  @extension_routes Application.compile_env(:wiki, :extension_routes, [])

  @doc """
  Macro that mounts routes for all registered extensions at compile time.
  Extensions register their routes as data in config under `:extension_routes`:

      config :wiki, extension_routes: [
        {"/ext/my_extension", [
          {"/some_path", MyExtension.Web.SomeLive, :index}
        ]}
      ]

  Usage in WikiWeb.Router:

      import Wiki.Extension.Web
      mount_extension_routes()
  """
  defmacro mount_extension_routes do
    for {prefix, paths} <- @extension_routes do
      path_routes =
        for {path, mod, action} <- paths do
          quote do
            live unquote(path), unquote(mod), unquote(action)
          end
        end

      quote do
        scope unquote(prefix) do
          pipe_through :browser
          unquote_splicing(path_routes)
        end
      end
    end
  end
end
