defmodule WikiWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use WikiWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true
  attr :breadcrumbs, :list, default: []
  slot :inner_block, required: true

  def app(assigns) do
    extensions =
      Wiki.Block.Extensions.registered()
      |> Enum.filter(fn mod ->
        Code.ensure_loaded?(mod) && function_exported?(mod, :home_path, 0)
      end)
      |> Enum.map(fn mod -> %{name: mod.name(), path: mod.home_path()} end)

    assigns = assign(assigns, :extensions, extensions)

    ~H"""
    <nav class="navbar bg-base-100 border-b border-base-300 px-4 min-h-12">
      <div class="flex-1 flex items-center gap-1">
        <.link navigate="/blocks" class="btn btn-ghost btn-sm btn-square" title="Blocks">
          <.icon name="hero-document-text" class="h-5 w-5" />
        </.link>
        <div :if={@extensions != []} class="dropdown">
          <button tabindex="0" class="btn btn-ghost btn-sm gap-1">
            Extensions
            <.icon name="hero-chevron-down-micro" class="h-3 w-3" />
          </button>
          <ul
            tabindex="0"
            class="dropdown-content menu bg-base-100 rounded-box z-10 w-44 p-1 shadow-md border border-base-300 text-sm"
          >
            <li :for={ext <- @extensions}>
              <.link navigate={ext.path}>{ext.name}</.link>
            </li>
          </ul>
        </div>
      </div>
    </nav>

    <div :if={@breadcrumbs != []} class="text-sm breadcrumbs px-5 py-2 border-b border-base-200 bg-base-50">
      <ul>
        <li :for={crumb <- @breadcrumbs}>
          <.link :if={crumb.path} navigate={crumb.path}>{crumb.label}</.link>
          <span :if={is_nil(crumb.path)} class="opacity-60">{crumb.label}</span>
        </li>
      </ul>
    </div>

    <.flash_group flash={@flash} />

    <main>
      {render_slot(@inner_block)}
    </main>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
