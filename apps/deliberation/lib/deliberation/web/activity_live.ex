defmodule Deliberation.Web.ActivityLive do
  use WikiWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, activity: nil, block_kinds: [])}
  end

  @impl true
  def handle_params(%{"activity_id" => activity_id}, _uri, socket) do
    activity = Wiki.Activity.get_group_activity(activity_id)

    socket =
      if activity do
        block_kinds = Deliberation.list_blocks_for_activity(activity_id)
        assign(socket, activity: activity, block_kinds: block_kinds, page_title: activity.name)
      else
        socket
        |> put_flash(:error, "Activity not found")
        |> push_navigate(to: "/ext/deliberation/activities")
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <div class="max-w-3xl mx-auto px-4 py-8">
      <div class="mb-8">
        <.link navigate="/ext/deliberation/activities" class="text-sm opacity-50 hover:opacity-100 flex items-center gap-1 mb-4">
          <.icon name="hero-arrow-left" class="h-4 w-4" /> All activities
        </.link>
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold">{@activity.name}</h1>
            <p class="text-sm opacity-60 mt-1">
              Deliberation extension ·
              <span class="badge badge-sm badge-ghost">{@activity.activity_type.name}</span>
              · <span class="opacity-60">{@activity.dimension.title}</span>
            </p>
          </div>
        </div>
      </div>

      <div class="space-y-3">
        <div
          :for={bk <- @block_kinds}
          class="card bg-base-100 border border-base-300 shadow-xs"
        >
          <div class="card-body py-4 px-5">
            <div class="flex items-center gap-2 mb-2">
              <span class={"badge badge-sm #{if bk.kind == "argument", do: "badge-primary", else: "badge-secondary"}"}>
                {bk.kind}
              </span>
              <code class="text-xs opacity-40">{bk.block.id}</code>
            </div>
            <div class="text-sm prose prose-sm max-w-none">
              {render_markdown(bk.block.block_content.content)}
            </div>
          </div>
        </div>

        <div :if={@block_kinds == []} class="text-center py-16 text-base-content/40">
          No blocks added to this activity yet.
        </div>
      </div>
    </div>
    """
  end

  defp render_markdown(content) do
    case Earmark.as_html(content) do
      {:ok, html, _} -> {:safe, html}
      {:error, html, _} -> {:safe, html}
    end
  end
end
