defmodule Deliberation.Web.ActivitiesLive do
  use WikiWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       activities: Deliberation.list_argument_activities(),
       page_title: "Argument Activities",
       breadcrumbs: [
         %{label: "Deliberation", path: "/ext/deliberation"},
         %{label: "Activities", path: nil}
       ]
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("create_activity", %{"name" => name}, socket) do
    case Deliberation.create_argument_activity(String.trim(name)) do
      {:ok, activity} ->
        {:noreply,
         socket
         |> assign(activities: [activity | socket.assigns.activities])
         |> put_flash(:info, "Activity \"#{activity.name}\" created")
         |> push_navigate(to: "/ext/deliberation/activities")}

      {:error, :not_configured} ->
        {:noreply, put_flash(socket, :error, "Deliberation extension not fully installed")}

      {:error, changeset} ->
        {:noreply, assign(socket, form_errors: changeset)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} breadcrumbs={@breadcrumbs}>
    <div class="max-w-3xl mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-8">
        <div>
          <h1 class="text-2xl font-bold">Argument Activities</h1>
          <p class="text-sm opacity-60 mt-1">Deliberation extension · Argument</p>
        </div>
        <div class="flex items-center gap-2">
          <.link navigate="/ext/deliberation/voting-activities" class="btn btn-ghost btn-sm">
            Voting Activities
          </.link>
          <.link :if={@live_action == :index} navigate="/ext/deliberation/activities/new" class="btn btn-primary btn-sm">
            New Activity
          </.link>
          <.link :if={@live_action == :new} navigate="/ext/deliberation/activities" class="btn btn-ghost btn-sm">
            Cancel
          </.link>
        </div>
      </div>

      <div :if={@live_action == :new} class="card bg-base-200 mb-8">
        <div class="card-body">
          <h2 class="card-title text-base">New Argument Activity</h2>
          <form phx-submit="create_activity">
            <div class="form-control mb-4">
              <label class="label">
                <span class="label-text">Name</span>
              </label>
              <input
                type="text"
                name="name"
                placeholder="e.g. Climate Policy Discussion"
                class="input input-bordered w-full"
                autofocus
              />
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
          navigate={"/ext/deliberation/activity/#{activity.id}"}
          class="card bg-base-100 border border-base-300 shadow-xs hover:border-base-content/20 transition-colors"
        >
          <div class="card-body py-4 px-5">
            <div class="flex items-center justify-between">
              <span class="font-medium">{activity.name}</span>
              <span class="badge badge-sm badge-ghost">
                {activity.activity_type.name}
              </span>
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
          No argument activities yet. Create one to get started.
        </div>
      </div>
    </div>
    </Layouts.app>
    """
  end
end
