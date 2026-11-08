defmodule Deliberation.Web.VotingActivitiesLive do
  use WikiWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       activities: Deliberation.list_voting_activities(),
       page_title: "Poll Activities",
       breadcrumbs: [
         %{label: "Deliberation", path: "/ext/deliberation"},
         %{label: "Poll", path: nil}
       ]
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("create_activity", %{"name" => name, "objective" => objective}, socket) do
    case Deliberation.create_voting_activity(String.trim(name), String.trim(objective)) do
      {:ok, group_activity, _voting_activity} ->
        {:noreply,
         socket
         |> assign(activities: [group_activity | socket.assigns.activities])
         |> put_flash(:info, "Voting activity \"#{group_activity.name}\" created")
         |> push_navigate(to: "/ext/deliberation/poll/#{group_activity.id}")}

      {:error, :not_configured} ->
        {:noreply, put_flash(socket, :error, "Deliberation extension not fully installed")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create voting activity")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} breadcrumbs={@breadcrumbs}>
    <div class="max-w-3xl mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-8">
        <div>
          <h1 class="text-2xl font-bold">Poll Activities</h1>
          <p class="text-sm opacity-60 mt-1">Deliberation extension · Poll</p>
        </div>
        <.link :if={@live_action == :index} navigate="/ext/deliberation/poll/new" class="btn btn-primary btn-sm">
          New Voting Activity
        </.link>
        <.link :if={@live_action == :new} navigate="/ext/deliberation/poll" class="btn btn-ghost btn-sm">
          Cancel
        </.link>
      </div>

      <div :if={@live_action == :new} class="card bg-base-200 mb-8">
        <div class="card-body">
          <h2 class="card-title text-base">New Voting Activity</h2>
          <form phx-submit="create_activity">
            <div class="form-control mb-4">
              <label class="label"><span class="label-text">Title</span></label>
              <input
                type="text"
                name="name"
                placeholder="e.g. Vote on Climate Proposals"
                class="input input-bordered w-full"
                autofocus
                required
              />
            </div>
            <div class="form-control mb-4">
              <label class="label"><span class="label-text">Objective <span class="opacity-50">(optional)</span></span></label>
              <textarea
                name="objective"
                placeholder="What is this vote trying to decide?"
                class="textarea textarea-bordered w-full"
                rows="2"
              ></textarea>
            </div>
            <div class="card-actions justify-end">
              <button type="submit" class="btn btn-primary btn-sm">Create</button>
            </div>
          </form>
        </div>
      </div>

      <div class="space-y-3">
        <.link
          :for={activity <- @activities}
          navigate={"/ext/deliberation/poll/#{activity.id}"}
          class="card bg-base-100 border border-base-300 shadow-xs hover:border-base-content/20 transition-colors"
        >
          <div class="card-body py-4 px-5">
            <div class="flex items-center justify-between">
              <span class="font-medium">{activity.name}</span>
              <span class="badge badge-sm badge-ghost">Voting</span>
            </div>
            <div class="flex items-center gap-3 mt-1">
              <code class="text-xs opacity-40">{activity.id}</code>
              <span class="text-xs opacity-50">
                Created {Calendar.strftime(activity.inserted_at, "%d %b %Y")}
              </span>
            </div>
          </div>
        </.link>

        <div :if={@activities == []} class="text-center py-16 text-base-content/40">
          No voting activities yet. Create one to get started.
        </div>
      </div>
    </div>
    </Layouts.app>
    """
  end
end
