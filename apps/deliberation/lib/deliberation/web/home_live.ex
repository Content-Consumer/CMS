defmodule Deliberation.Web.HomeLive do
  use WikiWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      page_title: "Deliberation",
      breadcrumbs: [%{label: "Deliberation", path: nil}]
    )}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} breadcrumbs={@breadcrumbs}>
      <div class="max-w-3xl mx-auto px-4 py-8">
        <div class="mb-8">
          <h1 class="text-2xl font-bold">Deliberation</h1>
          <p class="text-sm opacity-60 mt-1">Structured group deliberation for your content</p>
        </div>

        <div class="space-y-3">
          <.link navigate="/ext/deliberation/activities" class="card bg-base-100 border border-base-300 shadow-xs hover:border-base-content/20 transition-colors">
            <div class="card-body py-4 px-5 flex-row items-center justify-between">
              <div>
                <p class="font-medium">Argument Activities</p>
                <p class="text-sm opacity-50 mt-0.5">Manage structured argument sessions</p>
              </div>
              <.icon name="hero-arrow-right" class="h-4 w-4 opacity-40" />
            </div>
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
