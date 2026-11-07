defmodule Deliberation.Web.ActivityLive do
  use WikiWeb, :live_view

  alias Wiki.Metadata

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       activity: nil,
       block_kinds: [],
       breadcrumbs: [],
       upvote_field: nil,
       downvote_field: nil,
       vote_map: %{},
       rel_picker: nil,
       rel_search_query: "",
       rel_map: %{},
       rel_types: %{}
     )}
  end

  @impl true
  def handle_params(%{"activity_id" => activity_id}, _uri, socket) do
    activity = Wiki.Activity.get_group_activity(activity_id)

    socket =
      if activity do
        block_kinds = Deliberation.list_blocks_for_activity(activity_id)
        dim_id = activity.dimension.id

        upvote_field = Metadata.get_field_by_name_in_dimension("upvote", dim_id)
        downvote_field = Metadata.get_field_by_name_in_dimension("downvote", dim_id)

        vote_map = load_vote_map(block_kinds, upvote_field, downvote_field)

        supports_type = Wiki.BlockRelationship.get_type_by_name_in_dimension("supports", dim_id)
        attacks_type = Wiki.BlockRelationship.get_type_by_name_in_dimension("attacks", dim_id)

        block_ids = Enum.map(block_kinds, & &1.block.id)
        rel_map = if block_ids == [], do: %{}, else: Wiki.BlockRelationship.list_relations_for_blocks(block_ids)

        assign(socket,
          activity: activity,
          block_kinds: block_kinds,
          upvote_field: upvote_field,
          downvote_field: downvote_field,
          vote_map: vote_map,
          rel_types: %{"supports" => supports_type, "attacks" => attacks_type},
          rel_map: rel_map,
          rel_picker: nil,
          page_title: activity.name,
          breadcrumbs: [
            %{label: "Deliberation", path: "/ext/deliberation"},
            %{label: "Activities", path: "/ext/deliberation/activities"},
            %{label: activity.name, path: nil}
          ]
        )
      else
        socket
        |> put_flash(:error, "Activity not found")
        |> push_navigate(to: "/ext/deliberation/activities")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_vote", %{"block-id" => block_id, "field-id" => field_id}, socket) do
    user = socket.assigns.current_scope && socket.assigns.current_scope.user

    if is_nil(user) do
      {:noreply, put_flash(socket, :error, "You must be logged in to vote")}
    else
      current_value = get_in(socket.assigns.vote_map, [block_id, field_id]) || %{}

      result =
        if Metadata.has_voted?(current_value, user.id) do
          Metadata.remove_vote(block_id, field_id, user.id)
        else
          opposing = opposing_field(field_id, socket.assigns)
          if opposing, do: Metadata.remove_vote(block_id, opposing.id, user.id)
          Metadata.cast_vote(block_id, field_id, user.id)
        end

      case result do
        {:ok, _} ->
          vote_map = load_vote_map(socket.assigns.block_kinds, socket.assigns.upvote_field, socket.assigns.downvote_field)
          {:noreply, assign(socket, vote_map: vote_map)}

        _ ->
          {:noreply, put_flash(socket, :error, "Failed to register vote")}
      end
    end
  end

  @impl true
  def handle_event("show_rel_picker", %{"block-id" => id, "type" => type_name}, socket) do
    {:noreply, assign(socket, rel_picker: {id, type_name}, rel_search_query: "")}
  end

  @impl true
  def handle_event("hide_rel_picker", _, socket) do
    {:noreply, assign(socket, rel_picker: nil, rel_search_query: "")}
  end

  @impl true
  def handle_event("search_rel", %{"query" => query}, socket) do
    {:noreply, assign(socket, rel_search_query: query)}
  end

  @impl true
  def handle_event("create_rel", %{"argument-id" => argument_id}, socket) do
    {statement_id, type_name} = socket.assigns.rel_picker
    type = socket.assigns.rel_types[type_name]

    case Wiki.BlockRelationship.create_relation(argument_id, statement_id, type.id) do
      {:ok, _} ->
        block_ids = Enum.map(socket.assigns.block_kinds, & &1.block.id)
        rel_map = if block_ids == [], do: %{}, else: Wiki.BlockRelationship.list_relations_for_blocks(block_ids)
        {:noreply, assign(socket, rel_map: rel_map, rel_picker: nil, rel_search_query: "")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add relation")}
    end
  end

  @impl true
  def handle_event("delete_rel", %{"id" => id}, socket) do
    case Wiki.BlockRelationship.delete_relation(id) do
      {:ok, _} ->
        block_ids = Enum.map(socket.assigns.block_kinds, & &1.block.id)
        rel_map = if block_ids == [], do: %{}, else: Wiki.BlockRelationship.list_relations_for_blocks(block_ids)
        {:noreply, assign(socket, rel_map: rel_map)}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove relation")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} breadcrumbs={@breadcrumbs}>

    <div class="max-w-3xl mx-auto px-4 py-8">
      <div class="mb-8">
        <h1 class="text-2xl font-bold">{@activity.name}</h1>
        <p class="text-sm opacity-60 mt-1">
          <span class="badge badge-sm badge-ghost">{@activity.activity_type.name}</span>
          · {@activity.dimension.title}
        </p>
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
            <div :if={@upvote_field || @downvote_field} class="flex items-center gap-2 mt-3 pt-3 border-t border-base-200">
              <button
                :if={@upvote_field}
                phx-click="toggle_vote"
                phx-value-block-id={bk.block.id}
                phx-value-field-id={@upvote_field.id}
                class={"btn btn-sm rounded-full border gap-1 #{if voted?(bk.block.id, @upvote_field, @vote_map, @current_scope), do: "border-base-content font-semibold", else: "btn-ghost border-base-300"}"}
              >
                <.icon name="hero-arrow-up" class="h-4 w-4 shrink-0" />
                {vote_count_for(bk.block.id, @upvote_field, @vote_map)}
              </button>
              <button
                :if={@downvote_field}
                phx-click="toggle_vote"
                phx-value-block-id={bk.block.id}
                phx-value-field-id={@downvote_field.id}
                class={"btn btn-sm rounded-full border gap-1 #{if voted?(bk.block.id, @downvote_field, @vote_map, @current_scope), do: "border-base-content font-semibold", else: "btn-ghost border-base-300"}"}
              >
                <.icon name="hero-arrow-down" class="h-4 w-4 shrink-0" />
                {vote_count_for(bk.block.id, @downvote_field, @vote_map)}
              </button>
            </div>
            <%!-- Add argument buttons for statement blocks --%>
            <div :if={bk.kind == "statement" and (@rel_types["supports"] || @rel_types["attacks"])} class="flex gap-2 mt-3 pt-3 border-t border-base-200">
              <button
                :if={@rel_types["supports"]}
                phx-click="show_rel_picker"
                phx-value-block-id={bk.block.id}
                phx-value-type="supports"
                class="btn btn-xs btn-ghost gap-1"
              >
                <.icon name="hero-plus" class="h-3 w-3" /> Add supporting argument
              </button>
              <button
                :if={@rel_types["attacks"]}
                phx-click="show_rel_picker"
                phx-value-block-id={bk.block.id}
                phx-value-type="attacks"
                class="btn btn-xs btn-ghost gap-1"
              >
                <.icon name="hero-plus" class="h-3 w-3" /> Add attacking argument
              </button>
            </div>
            <%!-- Argument picker with search --%>
            <div :if={@rel_picker && elem(@rel_picker, 0) == bk.block.id} class="mt-3 pt-3 border-t border-base-200">
              <p class="text-xs font-medium opacity-60 mb-2">
                Pick an argument that <strong>{if elem(@rel_picker, 1) == "supports", do: "supports", else: "attacks"}</strong> this statement:
              </p>
              <form phx-change="search_rel" phx-submit="search_rel" class="mb-2">
                <input
                  type="text"
                  name="query"
                  value={@rel_search_query}
                  placeholder="Filter arguments…"
                  phx-debounce="150"
                  class="input input-sm input-bordered w-full"
                  autofocus
                />
              </form>
              <div class="flex flex-col gap-1 max-h-56 overflow-y-auto">
                <button
                  :for={arg <- filter_argument_blocks(@block_kinds, @rel_search_query)}
                  phx-click="create_rel"
                  phx-value-argument-id={arg.block.id}
                  class="btn btn-xs btn-ghost justify-start text-left h-auto py-2 whitespace-normal"
                >
                  {arg.block.block_content.content}
                </button>
              </div>
              <div :if={filter_argument_blocks(@block_kinds, @rel_search_query) == []} class="text-xs opacity-50 py-2">
                {if argument_blocks(@block_kinds) == [], do: "No argument blocks in this activity yet.", else: "No arguments match your search."}
              </div>
              <button phx-click="hide_rel_picker" class="btn btn-ghost btn-xs mt-2">Cancel</button>
            </div>
            <%!-- Existing relationships on statement blocks --%>
            <div :if={bk.kind == "statement" and @rel_map[bk.block.id] not in [nil, []]} class="mt-2 space-y-1">
              <div :for={rel <- (@rel_map[bk.block.id] || [])} class="flex items-center gap-2 text-xs">
                <span class={"badge badge-xs #{if rel.type.name == "supports", do: "badge-success", else: "badge-error"}"}>
                  {rel.type.label}
                </span>
                <span class="opacity-60 truncate flex-1">
                  {other_block_preview(rel, bk.block.id)}
                </span>
                <button phx-click="delete_rel" phx-value-id={rel.id} class="btn btn-ghost btn-xs text-error">
                  <.icon name="hero-x-mark" class="h-3 w-3" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <div :if={@block_kinds == []} class="text-center py-16 text-base-content/40">
          No blocks added to this activity yet.
        </div>
      </div>
    </div>
    </Layouts.app>
    """
  end

  defp opposing_field(field_id, %{upvote_field: up, downvote_field: down}) do
    cond do
      up && up.id == field_id -> down
      down && down.id == field_id -> up
      true -> nil
    end
  end

  defp load_vote_map(block_kinds, upvote_field, downvote_field) do
    block_ids = Enum.map(block_kinds, & &1.block.id)

    field_ids =
      [upvote_field && upvote_field.id, downvote_field && downvote_field.id]
      |> Enum.reject(&is_nil/1)

    if block_ids == [] or field_ids == [] do
      %{}
    else
      Metadata.get_values_for_blocks(block_ids, field_ids)
    end
  end

  defp voted?(block_id, field, vote_map, current_scope) do
    user = current_scope && current_scope.user
    value = get_in(vote_map, [block_id, field.id]) || %{}
    user && Metadata.has_voted?(value, user.id)
  end

  defp vote_count_for(block_id, field, vote_map) do
    value = get_in(vote_map, [block_id, field.id]) || %{}
    Metadata.vote_count(value)
  end

  defp statement_blocks(block_kinds), do: Enum.filter(block_kinds, &(&1.kind == "statement"))

  defp argument_blocks(block_kinds), do: Enum.filter(block_kinds, &(&1.kind == "argument"))

  defp filter_argument_blocks(block_kinds, query) do
    args = argument_blocks(block_kinds)
    if String.trim(query) == "" do
      args
    else
      q = String.downcase(query)
      Enum.filter(args, fn bk ->
        String.contains?(String.downcase(bk.block.block_content.content), q)
      end)
    end
  end

  defp other_block_preview(rel, block_id) do
    other = if rel.source_block_id == block_id, do: rel.target_block, else: rel.source_block
    String.slice(other.block_content.content, 0, 60)
  end

  defp render_markdown(content) do
    case Earmark.as_html(content) do
      {:ok, html, _} -> {:safe, html}
      {:error, html, _} -> {:safe, html}
    end
  end
end
