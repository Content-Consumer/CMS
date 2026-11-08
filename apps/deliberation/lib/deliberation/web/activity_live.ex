defmodule Deliberation.Web.ActivityLive do
  use WikiWeb, :live_view

  alias Wiki.Metadata

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       activity: nil,
       block_kinds: [],
       filtered_block_kinds: [],
       search_query: "",
       breadcrumbs: [],
       upvote_field: nil,
       downvote_field: nil,
       vote_map: %{},
       voter_map: %{},
       rel_picker: nil,
       rel_search_query: "",
       rel_map: %{},
       rel_types: %{},
       graph_data: %{statements: [], unlinked: []},
       focused_node: nil,
       focused_rels: %{supporting: [], attacking: [], as_source: []},
       sources: [],
       source_add_mode: nil,
       source_text_input: "",
       source_search_query: "",
       source_search_results: [],
       source_remove_warning: nil
     )}
  end

  # ── Node detail ──────────────────────────────────────────────────────────────

  @impl true
  def handle_params(%{"activity_id" => activity_id, "block_id" => block_id}, _uri, socket) do
    socket = load_activity(socket, activity_id)

    socket =
      if socket.assigns.activity do
        activity = socket.assigns.activity
        block_kinds = socket.assigns.block_kinds
        rel_map = socket.assigns.rel_map
        rel_types = socket.assigns.rel_types

        focused_bk = Enum.find(block_kinds, &(&1.block.id == block_id))

        {focused_node, focused_rels} =
          if focused_bk do
            rels = Map.get(rel_map, block_id, [])
            supports_type = rel_types["supports"]
            attacks_type = rel_types["attacks"]

            supporting =
              Enum.filter(rels, fn rel ->
                supports_type &&
                  rel.type_id == supports_type.id &&
                  rel.target_block_id == block_id
              end)

            attacking =
              Enum.filter(rels, fn rel ->
                attacks_type &&
                  rel.type_id == attacks_type.id &&
                  rel.target_block_id == block_id
              end)

            # For argument nodes: which statements does it relate to (as source)?
            as_source =
              Enum.flat_map(rel_map, fn {_bid, block_rels} -> block_rels end)
              |> Enum.filter(&(&1.source_block_id == block_id))
              |> Enum.uniq_by(& &1.id)

            {focused_bk, %{supporting: supporting, attacking: attacking, as_source: as_source}}
          else
            {nil, %{supporting: [], attacking: [], as_source: []}}
          end

        node_label =
          if focused_node,
            do: String.slice(focused_node.block.block_content.content, 0, 40) <> "…",
            else: "Node"

        assign(socket,
          focused_node: focused_node,
          focused_rels: focused_rels,
          breadcrumbs: [
            %{label: "Deliberation", path: "/ext/deliberation"},
            %{label: "Argument", path: "/ext/deliberation/argument"},
            %{label: activity.name, path: "/ext/deliberation/argument/#{activity.id}/graph"},
            %{label: node_label, path: nil}
          ]
        )
      else
        socket
      end

    {:noreply, socket}
  end

  # ── List / Graph ─────────────────────────────────────────────────────────────

  @impl true
  def handle_params(%{"activity_id" => activity_id}, _uri, socket) do
    socket = load_activity(socket, activity_id)

    socket =
      if socket.assigns.activity do
        activity = socket.assigns.activity
        live_action = socket.assigns.live_action

        assign(socket,
          focused_node: nil,
          breadcrumbs: [
            %{label: "Deliberation", path: "/ext/deliberation"},
            %{label: "Argument", path: "/ext/deliberation/argument"},
            %{label: activity.name, path: nil}
          ],
          page_title:
            case live_action do
              :graph -> "#{activity.name} · Graph"
              :sources -> "#{activity.name} · Sources"
              _ -> activity.name
            end
        )
      else
        socket
      end

    {:noreply, socket}
  end

  # ── Events ───────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("search_activity", %{"query" => query}, socket) do
    {:noreply, apply_search(socket, query)}
  end

  @impl true
  def handle_event("toggle_vote", %{"block-id" => block_id, "field-id" => field_id}, socket) do
    scope = socket.assigns.current_scope

    if is_nil(scope && scope.user) do
      {:noreply, put_flash(socket, :error, "You must be logged in to vote")}
    else
      user = scope.user
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
          vote_map =
            load_vote_map(
              socket.assigns.block_kinds,
              socket.assigns.upvote_field,
              socket.assigns.downvote_field
            )

          voter_map =
            load_voter_map(vote_map, socket.assigns.upvote_field, socket.assigns.downvote_field)

          {:noreply, assign(socket, vote_map: vote_map, voter_map: voter_map)}

        _ ->
          {:noreply, put_flash(socket, :error, "Failed to register vote")}
      end
    end
  end

  @impl true
  def handle_event("show_rel_picker", %{"block-id" => id, "type" => type_name}, socket) do
    scope = socket.assigns.current_scope

    if scope && scope.user do
      {:noreply, assign(socket, rel_picker: {id, type_name}, rel_search_query: "")}
    else
      {:noreply, put_flash(socket, :error, "You must be logged in")}
    end
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
    scope = socket.assigns.current_scope

    if is_nil(scope && scope.user) do
      {:noreply, put_flash(socket, :error, "You must be logged in")}
    else
      {statement_id, type_name} = socket.assigns.rel_picker
      type = socket.assigns.rel_types[type_name]

      case Wiki.BlockRelationship.create_relation(argument_id, statement_id, type.id) do
        {:ok, _} ->
          block_ids = Enum.map(socket.assigns.block_kinds, & &1.block.id)
          rel_map =
            if block_ids == [],
              do: %{},
              else: Wiki.BlockRelationship.list_relations_for_blocks(block_ids)

          {:noreply,
           socket
           |> assign(rel_map: rel_map, rel_picker: nil, rel_search_query: "")
           |> apply_search(socket.assigns.search_query)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to add relation")}
      end
    end
  end

  @impl true
  def handle_event("delete_rel", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    if is_nil(scope && scope.user) do
      {:noreply, put_flash(socket, :error, "You must be logged in")}
    else
      case Wiki.BlockRelationship.delete_relation(id) do
        {:ok, _} ->
          block_ids = Enum.map(socket.assigns.block_kinds, & &1.block.id)
          rel_map =
            if block_ids == [],
              do: %{},
              else: Wiki.BlockRelationship.list_relations_for_blocks(block_ids)

          {:noreply,
           socket
           |> assign(rel_map: rel_map)
           |> apply_search(socket.assigns.search_query)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to remove relation")}
      end
    end
  end

  # ── Source events ────────────────────────────────────────────────────────────

  @impl true
  def handle_event("set_source_add_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, source_add_mode: mode, source_text_input: "", source_search_query: "", source_search_results: [])}
  end

  @impl true
  def handle_event("cancel_source_add", _, socket) do
    {:noreply, assign(socket, source_add_mode: nil, source_text_input: "", source_search_query: "", source_search_results: [])}
  end

  @impl true
  def handle_event("search_source_blocks", %{"query" => query}, socket) do
    results = if String.trim(query) == "", do: [], else: Wiki.TextBlock.search_blocks(query)
    source_block_ids = MapSet.new(socket.assigns.sources, & &1.block_id)
    filtered = Enum.reject(results, &MapSet.member?(source_block_ids, &1.id))
    {:noreply, assign(socket, source_search_query: query, source_search_results: filtered)}
  end

  @impl true
  def handle_event("add_existing_source", %{"block-id" => block_id}, socket) do
    scope = socket.assigns.current_scope
    user_id = scope && scope.user && scope.user.id
    activity_id = socket.assigns.activity.id

    case Deliberation.add_source_block(block_id, activity_id, user_id) do
      {:ok, _} ->
        sources = Deliberation.list_sources_for_activity(activity_id)
        {:noreply, assign(socket, sources: sources, source_add_mode: nil, source_search_query: "", source_search_results: [])}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add source")}
    end
  end

  @impl true
  def handle_event("add_source_text", %{"content" => content}, socket) do
    scope = socket.assigns.current_scope
    user_id = scope && scope.user && scope.user.id
    activity_id = socket.assigns.activity.id

    if String.trim(content) == "" do
      {:noreply, put_flash(socket, :error, "Content cannot be empty")}
    else
      case Deliberation.create_source_text_block(content, activity_id, user_id) do
        {:ok, _} ->
          sources = Deliberation.list_sources_for_activity(activity_id)
          {:noreply, assign(socket, sources: sources, source_add_mode: nil, source_text_input: "")}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to create source block")}
      end
    end
  end

  @impl true
  def handle_event("remove_source", %{"block-id" => block_id}, socket) do
    activity_id = socket.assigns.activity.id

    case Deliberation.remove_source_block(block_id, activity_id) do
      {:ok, _} ->
        sources = Deliberation.list_sources_for_activity(activity_id)
        {:noreply, assign(socket, sources: sources, source_remove_warning: nil)}
      {:error, :in_use} ->
        {:noreply, assign(socket, source_remove_warning: block_id)}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove source")}
    end
  end

  @impl true
  def handle_event("dismiss_source_warning", _, socket) do
    {:noreply, assign(socket, source_remove_warning: nil)}
  end

  # ── Render ───────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} breadcrumbs={@breadcrumbs} current_scope={@current_scope}>
    <div class="max-w-4xl mx-auto px-4 py-8">
      <div class="mb-6">
        <h1 class="text-2xl font-bold">{@activity.name}</h1>
        <p class="text-sm opacity-60 mt-1">
          <span class="badge badge-sm bg-ink-100 text-ink-600 border-0">{@activity.activity_type.name}</span>
          · {@activity.dimension.title}
        </p>
      </div>

      <%!-- Tabs + search bar (not shown for node detail) --%>
      <div :if={@live_action != :node}>
        <div class="flex items-center gap-3 mb-4">
          <div role="tablist" class="tabs tabs-bordered shrink-0">
            <.link
              role="tab"
              navigate={"/ext/deliberation/argument/#{@activity.id}"}
              class={"tab #{if @live_action == :show, do: "tab-active"}"}
            >
              List
            </.link>
            <.link
              role="tab"
              navigate={"/ext/deliberation/argument/#{@activity.id}/graph"}
              class={"tab #{if @live_action == :graph, do: "tab-active"}"}
            >
              Graph
            </.link>
            <.link
              role="tab"
              navigate={"/ext/deliberation/argument/#{@activity.id}/sources"}
              class={"tab #{if @live_action == :sources, do: "tab-active"}"}
            >
              Sources
              <span :if={@sources != []} class="badge badge-sm ml-1">{length(@sources)}</span>
            </.link>
          </div>
          <form :if={@live_action != :sources} phx-change="search_activity" phx-submit="search_activity" class="flex-1">
            <input
              type="text"
              name="query"
              value={@search_query}
              placeholder="Search blocks…"
              phx-debounce="200"
              class="input input-bordered input-sm w-full"
            />
          </form>
        </div>
        <p :if={@live_action != :sources && @search_query != "" && @filtered_block_kinds == []} class="text-sm opacity-50 py-4 text-center">
          No blocks match "<em>{@search_query}</em>".
        </p>
        <p :if={@live_action != :sources && @search_query != "" && @filtered_block_kinds != []} class="text-xs opacity-40 mb-4">
          {length(@filtered_block_kinds)} of {length(@block_kinds)} blocks shown
        </p>
      </div>

      <%!-- Node detail (:node) --%>
      <div :if={@live_action == :node}>
        <.link
          navigate={"/ext/deliberation/argument/#{@activity.id}/graph"}
          class="btn btn-ghost btn-sm gap-1 mb-4 -ml-1"
        >
          <.icon name="hero-arrow-left" class="h-4 w-4" /> Back to graph
        </.link>

        <div :if={is_nil(@focused_node)} class="text-center py-16 text-base-content/40">
          Block not found in this activity.
        </div>

        <div :if={@focused_node}>
          <div class="card bg-base-100 border border-base-300 mb-6">
            <div class="card-body py-4 px-5">
              <div class="flex items-center gap-2 mb-3 flex-wrap">
                <span class={"badge badge-sm border-0 #{kind_badge_class(@focused_node.kind)}"}>
                  {@focused_node.kind}
                </span>
                <.link href={"/blocks/#{@focused_node.block.id}"} class="text-xs opacity-40 font-mono hover:opacity-70 hover:underline">
                  {@focused_node.block.id}
                </.link>
                <span :if={@focused_node.created_by} class="text-xs opacity-40 ml-auto">
                  {@focused_node.created_by.email}
                </span>
              </div>
              <div class="text-sm prose prose-sm max-w-none">
                {render_markdown(@focused_node.block.block_content.content)}
              </div>
              <div :if={(@upvote_field || @downvote_field) && not is_nil(@current_scope && @current_scope.user)} class="flex items-center gap-2 mt-3 pt-3 border-t border-base-200">
                <button
                  :if={@upvote_field}
                  phx-click="toggle_vote"
                  phx-value-block-id={@focused_node.block.id}
                  phx-value-field-id={@upvote_field.id}
                  title={voters_for(@focused_node.block.id, @upvote_field, @voter_map) |> Enum.map(& &1.email) |> Enum.join(", ")}
                  class={"btn btn-sm rounded-full border gap-1 #{if voted?(@focused_node.block.id, @upvote_field, @vote_map, @current_scope), do: "border-base-content font-semibold", else: "btn-ghost border-base-300"}"}
                >
                  <.icon name="hero-arrow-up" class="h-4 w-4 shrink-0" />
                  {vote_count_for(@focused_node.block.id, @upvote_field, @vote_map)}
                </button>
                <button
                  :if={@downvote_field}
                  phx-click="toggle_vote"
                  phx-value-block-id={@focused_node.block.id}
                  phx-value-field-id={@downvote_field.id}
                  title={voters_for(@focused_node.block.id, @downvote_field, @voter_map) |> Enum.map(& &1.email) |> Enum.join(", ")}
                  class={"btn btn-sm rounded-full border gap-1 #{if voted?(@focused_node.block.id, @downvote_field, @vote_map, @current_scope), do: "border-base-content font-semibold", else: "btn-ghost border-base-300"}"}
                >
                  <.icon name="hero-arrow-down" class="h-4 w-4 shrink-0" />
                  {vote_count_for(@focused_node.block.id, @downvote_field, @vote_map)}
                </button>
              </div>
            </div>
          </div>

          <%!-- Statement node: show its arguments grouped --%>
          <div :if={@focused_node.kind == "statement"}>
            <div :if={@focused_rels.supporting != [] || @focused_rels.attacking != []}>
              <div :if={@focused_rels.supporting != []} class="mb-6">
                <h2 class="text-xs font-semibold uppercase tracking-widest opacity-50 mb-3">
                  Supporting arguments ({length(@focused_rels.supporting)})
                </h2>
                <div class="space-y-2">
                  <.link
                    :for={rel <- @focused_rels.supporting}
                    navigate={"/ext/deliberation/argument/#{@activity.id}/node/#{rel.source_block_id}"}
                    class="card bg-base-100 border border-brand-200 hover:border-brand-400 transition-colors cursor-pointer block"
                  >
                    <div class="card-body py-3 px-4 text-sm">
                      {String.slice(rel.source_block.block_content.content, 0, 200)}
                    </div>
                  </.link>
                </div>
              </div>
              <div :if={@focused_rels.attacking != []} class="mb-6">
                <h2 class="text-xs font-semibold uppercase tracking-widest opacity-50 mb-3">
                  Attacking arguments ({length(@focused_rels.attacking)})
                </h2>
                <div class="space-y-2">
                  <.link
                    :for={rel <- @focused_rels.attacking}
                    navigate={"/ext/deliberation/argument/#{@activity.id}/node/#{rel.source_block_id}"}
                    class="card bg-base-100 border border-ink-200 hover:border-ink-400 transition-colors cursor-pointer block"
                  >
                    <div class="card-body py-3 px-4 text-sm">
                      {String.slice(rel.source_block.block_content.content, 0, 200)}
                    </div>
                  </.link>
                </div>
              </div>
            </div>
            <div :if={@focused_rels.supporting == [] && @focused_rels.attacking == []} class="text-sm opacity-40 py-4">
              No arguments linked to this statement yet.
            </div>
            <%!-- Add argument picker --%>
            <div :if={not is_nil(@current_scope && @current_scope.user) && (@rel_types["supports"] || @rel_types["attacks"])} class="flex gap-2 pt-2">
              <button
                :if={@rel_types["supports"]}
                phx-click="show_rel_picker"
                phx-value-block-id={@focused_node.block.id}
                phx-value-type="supports"
                class="btn btn-xs btn-ghost gap-1"
              >
                <.icon name="hero-plus" class="h-3 w-3" /> Add supporting argument
              </button>
              <button
                :if={@rel_types["attacks"]}
                phx-click="show_rel_picker"
                phx-value-block-id={@focused_node.block.id}
                phx-value-type="attacks"
                class="btn btn-xs btn-ghost gap-1"
              >
                <.icon name="hero-plus" class="h-3 w-3" /> Add attacking argument
              </button>
            </div>
            <div :if={@rel_picker && elem(@rel_picker, 0) == @focused_node.block.id} class="mt-3 pt-3 border-t border-base-200">
              <p class="text-xs font-medium opacity-60 mb-2">
                Pick an argument that <strong>{if elem(@rel_picker, 1) == "supports", do: "supports", else: "attacks"}</strong> this statement:
              </p>
              <form phx-change="search_rel" phx-submit="search_rel" class="mb-2">
                <input type="text" name="query" value={@rel_search_query} placeholder="Filter arguments…" phx-debounce="150" class="input input-sm input-bordered w-full" autofocus />
              </form>
              <div class="flex flex-col gap-1 max-h-56 overflow-y-auto">
                <button :for={arg <- filter_argument_blocks(@block_kinds, @rel_search_query)} phx-click="create_rel" phx-value-argument-id={arg.block.id} class="btn btn-xs btn-ghost justify-start text-left h-auto py-2 whitespace-normal">
                  {arg.block.block_content.content}
                </button>
              </div>
              <div :if={filter_argument_blocks(@block_kinds, @rel_search_query) == []} class="text-xs opacity-50 py-2">
                {if argument_blocks(@block_kinds) == [], do: "No argument blocks in this activity yet.", else: "No arguments match your search."}
              </div>
              <button phx-click="hide_rel_picker" class="btn btn-ghost btn-xs mt-2">Cancel</button>
            </div>
          </div>

          <%!-- Argument node: show which statements it relates to --%>
          <div :if={@focused_node.kind == "argument" && @focused_rels.as_source != []}>
            <h2 class="text-xs font-semibold uppercase tracking-widest opacity-50 mb-3">
              Relates to ({length(@focused_rels.as_source)})
            </h2>
            <div class="space-y-2">
              <.link
                :for={rel <- @focused_rels.as_source}
                navigate={"/ext/deliberation/argument/#{@activity.id}/node/#{rel.target_block_id}"}
                class="card bg-base-100 border border-base-300 hover:border-base-content/20 transition-colors cursor-pointer block"
              >
                <div class="card-body py-3 px-4">
                  <span class={"badge badge-xs border-0 mr-2 #{if rel.type.name == "supports", do: "bg-brand-100 text-brand-700", else: "bg-ink-200 text-ink-700"}"}>
                    {rel.type.label}
                  </span>
                  <span class="text-sm">{String.slice(rel.target_block.block_content.content, 0, 150)}</span>
                </div>
              </.link>
            </div>
          </div>
        </div>
      </div>

      <%!-- List view (:show) --%>
      <div :if={@live_action == :show}>
        <div class="space-y-3">
          <div :for={bk <- @filtered_block_kinds} class="card bg-base-100 border border-base-300 shadow-xs">
            <div class="card-body py-4 px-5">
              <div class="flex items-center gap-2 mb-2 flex-wrap">
                <span class={"badge badge-sm border-0 #{kind_badge_class(bk.kind)}"}>
                  {bk.kind}
                </span>
                <.link href={"/blocks/#{bk.block.id}"} class="text-xs opacity-40 font-mono hover:opacity-70 hover:underline">
                  {bk.block.id}
                </.link>
                <span :if={bk.created_by} class="text-xs opacity-40 ml-auto">
                  Added by {bk.created_by.email}
                </span>
              </div>
              <div class="text-sm prose prose-sm max-w-none">
                {render_markdown(bk.block.block_content.content)}
              </div>
              <div :if={(@upvote_field || @downvote_field) && not is_nil(@current_scope && @current_scope.user)} class="flex items-center gap-2 mt-3 pt-3 border-t border-base-200">
                <button
                  :if={@upvote_field}
                  phx-click="toggle_vote"
                  phx-value-block-id={bk.block.id}
                  phx-value-field-id={@upvote_field.id}
                  title={voters_for(bk.block.id, @upvote_field, @voter_map) |> Enum.map(& &1.email) |> Enum.join(", ")}
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
                  title={voters_for(bk.block.id, @downvote_field, @voter_map) |> Enum.map(& &1.email) |> Enum.join(", ")}
                  class={"btn btn-sm rounded-full border gap-1 #{if voted?(bk.block.id, @downvote_field, @vote_map, @current_scope), do: "border-base-content font-semibold", else: "btn-ghost border-base-300"}"}
                >
                  <.icon name="hero-arrow-down" class="h-4 w-4 shrink-0" />
                  {vote_count_for(bk.block.id, @downvote_field, @vote_map)}
                </button>
              </div>
              <div :if={bk.kind == "statement" && not is_nil(@current_scope && @current_scope.user) && (@rel_types["supports"] || @rel_types["attacks"])} class="flex gap-2 mt-3 pt-3 border-t border-base-200">
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
              <div :if={@rel_picker && elem(@rel_picker, 0) == bk.block.id} class="mt-3 pt-3 border-t border-base-200">
                <p class="text-xs font-medium opacity-60 mb-2">
                  Pick an argument that <strong>{if elem(@rel_picker, 1) == "supports", do: "supports", else: "attacks"}</strong> this statement:
                </p>
                <form phx-change="search_rel" phx-submit="search_rel" class="mb-2">
                  <input type="text" name="query" value={@rel_search_query} placeholder="Filter arguments…" phx-debounce="150" class="input input-sm input-bordered w-full" autofocus />
                </form>
                <div class="flex flex-col gap-1 max-h-56 overflow-y-auto">
                  <button :for={arg <- filter_argument_blocks(@block_kinds, @rel_search_query)} phx-click="create_rel" phx-value-argument-id={arg.block.id} class="btn btn-xs btn-ghost justify-start text-left h-auto py-2 whitespace-normal">
                    {arg.block.block_content.content}
                  </button>
                </div>
                <div :if={filter_argument_blocks(@block_kinds, @rel_search_query) == []} class="text-xs opacity-50 py-2">
                  {if argument_blocks(@block_kinds) == [], do: "No argument blocks in this activity yet.", else: "No arguments match your search."}
                </div>
                <button phx-click="hide_rel_picker" class="btn btn-ghost btn-xs mt-2">Cancel</button>
              </div>
              <div :if={bk.kind == "statement" && @rel_map[bk.block.id] not in [nil, []]} class="mt-2 space-y-1">
                <div :for={rel <- (@rel_map[bk.block.id] || [])} class="flex items-center gap-2 text-xs">
                  <span class={"badge badge-xs border-0 #{rel_badge_class(rel.type.name)}"}>
                    {rel.type.label}
                  </span>
                  <span class="opacity-60 truncate flex-1">
                    {other_block_preview(rel, bk.block.id)}
                  </span>
                  <button :if={not is_nil(@current_scope && @current_scope.user)} phx-click="delete_rel" phx-value-id={rel.id} class="btn btn-ghost btn-xs text-error">
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

      <%!-- Sources view (:sources) --%>
      <div :if={@live_action == :sources}>
        <div class="flex items-center justify-between mb-4">
          <p class="text-sm opacity-50">Blocks in this pool can be used as statements and arguments.</p>
          <div :if={is_nil(@source_add_mode)} class="flex gap-2">
            <button phx-click="set_source_add_mode" phx-value-mode="search" class="btn btn-sm btn-ghost gap-1">
              <.icon name="hero-magnifying-glass" class="h-4 w-4" /> Add existing
            </button>
            <button phx-click="set_source_add_mode" phx-value-mode="text" class="btn btn-sm btn-primary gap-1">
              <.icon name="hero-plus" class="h-4 w-4" /> New text block
            </button>
          </div>
        </div>

        <%!-- Add existing block panel --%>
        <div :if={@source_add_mode == "search"} class="card bg-base-100 border border-base-300 mb-4">
          <div class="card-body py-4 px-5">
            <h3 class="font-medium text-sm mb-3">Search existing blocks</h3>
            <form phx-change="search_source_blocks" phx-submit="search_source_blocks" class="mb-3">
              <input
                type="text"
                name="query"
                value={@source_search_query}
                placeholder="Search blocks by content…"
                phx-debounce="200"
                class="input input-bordered input-sm w-full"
                autofocus
              />
            </form>
            <div :if={@source_search_results != []} class="space-y-1 max-h-64 overflow-y-auto">
              <button
                :for={block <- @source_search_results}
                phx-click="add_existing_source"
                phx-value-block-id={block.id}
                class="w-full text-left btn btn-ghost btn-sm h-auto py-2 px-3 whitespace-normal"
              >
                <span class="text-xs opacity-50 font-mono mr-2">{String.slice(block.id, 0, 8)}</span>
                {String.slice(block.block_content.content, 0, 120)}
              </button>
            </div>
            <p :if={@source_search_query != "" && @source_search_results == []} class="text-sm opacity-50 py-2">No blocks found.</p>
            <div class="flex justify-end mt-3">
              <button phx-click="cancel_source_add" class="btn btn-ghost btn-sm">Cancel</button>
            </div>
          </div>
        </div>

        <%!-- New text block panel --%>
        <div :if={@source_add_mode == "text"} class="card bg-base-100 border border-base-300 mb-4">
          <div class="card-body py-4 px-5">
            <h3 class="font-medium text-sm mb-3">New text block</h3>
            <form phx-submit="add_source_text">
              <textarea
                name="content"
                placeholder="Enter block content…"
                class="textarea textarea-bordered w-full text-sm"
                rows="4"
                autofocus
              ></textarea>
              <div class="flex justify-end gap-2 mt-3">
                <button type="button" phx-click="cancel_source_add" class="btn btn-ghost btn-sm">Cancel</button>
                <button type="submit" class="btn btn-primary btn-sm">Add source</button>
              </div>
            </form>
          </div>
        </div>

        <%!-- Source list --%>
        <div :if={@sources == [] && is_nil(@source_add_mode)} class="text-center py-16 text-base-content/40 text-sm">
          No sources added yet. Add blocks to build the source pool.
        </div>
        <div class="space-y-2">
          <div :for={src <- @sources} class="card bg-base-100 border border-base-300">
            <div class="card-body py-3 px-4">
              <div :if={@source_remove_warning == src.block_id} class="mb-3 p-3 bg-warning/10 border border-warning rounded-lg text-sm">
                <p class="font-medium text-warning mb-1">Cannot remove — block is in use</p>
                <p class="opacity-70 text-xs">This block is used as a statement or argument in this activity. Remove those first, then try again.</p>
                <button phx-click="dismiss_source_warning" class="btn btn-ghost btn-xs mt-2">Dismiss</button>
              </div>
              <div class="flex items-start gap-3">
                <div class="flex-1 min-w-0">
                  <.link href={"/blocks/#{src.block.id}"} class="text-xs opacity-40 font-mono hover:opacity-70 hover:underline block mb-1">
                    {src.block.id}
                  </.link>
                  <p class="text-sm">{String.slice(src.block.block_content.content, 0, 200)}</p>
                </div>
                <button
                  :if={not is_nil(@current_scope && @current_scope.user)}
                  phx-click="remove_source"
                  phx-value-block-id={src.block_id}
                  class="btn btn-ghost btn-xs text-error shrink-0"
                  title="Remove source"
                >
                  <.icon name="hero-trash" class="h-4 w-4" />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Graph view (:graph) --%>

      <div :if={@live_action == :graph}>
        <div :if={@block_kinds == []} class="text-center py-16 text-base-content/40">
          No blocks added to this activity yet.
        </div>
        <div :if={@block_kinds != []} class="space-y-8">
          <%!-- Statements with their arguments --%>
          <div :for={stmt_data <- @graph_data.statements} class="relative">
            <.link
              navigate={"/ext/deliberation/argument/#{@activity.id}/node/#{stmt_data.bk.block.id}"}
              class="card bg-base-100 border-2 border-accent-200 hover:border-accent-400 shadow-xs transition-colors cursor-pointer block"
            >
              <div class="card-body py-3 px-4">
                <div class="flex items-start gap-2">
                  <span class="badge badge-sm border-0 bg-accent-100 text-accent-700 shrink-0 mt-0.5">statement</span>
                  <p class="text-sm">{stmt_data.bk.block.block_content.content}</p>
                </div>
                <div :if={stmt_data.supporting != [] || stmt_data.attacking != []} class="flex gap-2 mt-1 flex-wrap">
                  <span :if={stmt_data.supporting != []} class="text-xs opacity-40 flex items-center gap-1">
                    <span class="inline-block w-2 h-2 rounded-full bg-brand-400"></span>
                    {length(stmt_data.supporting)} supporting
                  </span>
                  <span :if={stmt_data.attacking != []} class="text-xs opacity-40 flex items-center gap-1">
                    <span class="inline-block w-2 h-2 rounded-full bg-ink-400"></span>
                    {length(stmt_data.attacking)} attacking
                  </span>
                </div>
              </div>
            </.link>

            <div :if={stmt_data.supporting != [] || stmt_data.attacking != []} class="mt-2 ml-4 grid grid-cols-1 sm:grid-cols-2 gap-3">
              <%!-- Supporting arguments --%>
              <div :if={stmt_data.supporting != []}>
                <p class="text-xs font-medium opacity-40 mb-2 flex items-center gap-1">
                  <span class="inline-block w-2 h-2 rounded-full bg-brand-400"></span>
                  Supports
                </p>
                <div class="space-y-2">
                  <.link
                    :for={item <- stmt_data.supporting}
                    navigate={"/ext/deliberation/argument/#{@activity.id}/node/#{item.bk.block.id}"}
                    class="card bg-base-50 border border-brand-100 hover:border-brand-300 transition-colors cursor-pointer block"
                  >
                    <div class="card-body py-2 px-3">
                      <p class="text-xs line-clamp-3">{item.bk.block.block_content.content}</p>
                    </div>
                  </.link>
                </div>
              </div>
              <%!-- Attacking arguments --%>
              <div :if={stmt_data.attacking != []}>
                <p class="text-xs font-medium opacity-40 mb-2 flex items-center gap-1">
                  <span class="inline-block w-2 h-2 rounded-full bg-ink-400"></span>
                  Attacks
                </p>
                <div class="space-y-2">
                  <.link
                    :for={item <- stmt_data.attacking}
                    navigate={"/ext/deliberation/argument/#{@activity.id}/node/#{item.bk.block.id}"}
                    class="card bg-base-50 border border-ink-100 hover:border-ink-300 transition-colors cursor-pointer block"
                  >
                    <div class="card-body py-2 px-3">
                      <p class="text-xs line-clamp-3">{item.bk.block.block_content.content}</p>
                    </div>
                  </.link>
                </div>
              </div>
            </div>
          </div>

          <%!-- Unlinked arguments --%>
          <div :if={@graph_data.unlinked != []}>
            <p class="text-xs font-semibold uppercase tracking-widest opacity-40 mb-3">
              Unlinked arguments ({length(@graph_data.unlinked)})
            </p>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
              <.link
                :for={bk <- @graph_data.unlinked}
                navigate={"/ext/deliberation/argument/#{@activity.id}/node/#{bk.block.id}"}
                class="card bg-base-100 border border-brand-100 hover:border-brand-300 transition-colors cursor-pointer block"
              >
                <div class="card-body py-2 px-3">
                  <div class="flex items-center gap-2 mb-1">
                    <span class="badge badge-xs border-0 bg-brand-100 text-brand-700">argument</span>
                  </div>
                  <p class="text-xs line-clamp-2">{bk.block.block_content.content}</p>
                </div>
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    </Layouts.app>
    """
  end

  # ── Private helpers ───────────────────────────────────────────────────────────

  defp load_activity(socket, activity_id) do
    activity = Wiki.Activity.get_group_activity(activity_id)

    if activity do
      all_block_kinds = Deliberation.list_blocks_for_activity(activity_id)
      block_kinds = Enum.reject(all_block_kinds, &(&1.kind == "source"))
      sources = Deliberation.list_sources_for_activity(activity_id)
      dim_id = activity.dimension.id

      upvote_field = Metadata.get_field_by_name_in_dimension("upvote", dim_id)
      downvote_field = Metadata.get_field_by_name_in_dimension("downvote", dim_id)

      vote_map = load_vote_map(block_kinds, upvote_field, downvote_field)
      voter_map = load_voter_map(vote_map, upvote_field, downvote_field)

      supports_type = Wiki.BlockRelationship.get_type_by_name_in_dimension("supports", dim_id)
      attacks_type = Wiki.BlockRelationship.get_type_by_name_in_dimension("attacks", dim_id)

      block_ids = Enum.map(block_kinds, & &1.block.id)
      rel_map = if block_ids == [], do: %{}, else: Wiki.BlockRelationship.list_relations_for_blocks(block_ids)

      rel_types = %{"supports" => supports_type, "attacks" => attacks_type}
      graph_data = build_graph_data(block_kinds, rel_map, rel_types)

      scope =
        socket.assigns.current_scope
        |> Wiki.Accounts.Scope.with_dimension(activity.dimension)
        |> Wiki.Accounts.Scope.with_activity(activity)

      socket
      |> assign(
        current_scope: scope,
        activity: activity,
        block_kinds: block_kinds,
        sources: sources,
        upvote_field: upvote_field,
        downvote_field: downvote_field,
        vote_map: vote_map,
        voter_map: voter_map,
        rel_types: rel_types,
        rel_map: rel_map,
        rel_picker: nil,
        page_title: activity.name
      )
      |> apply_search(socket.assigns[:search_query] || "")
    else
      socket
      |> put_flash(:error, "Activity not found")
      |> push_navigate(to: "/ext/deliberation/argument")
    end
  end

  defp build_graph_data(block_kinds, rel_map, rel_types) do
    statements = Enum.filter(block_kinds, &(&1.kind == "statement"))
    arguments = Enum.filter(block_kinds, &(&1.kind == "argument"))
    supports_type = rel_types["supports"]
    attacks_type = rel_types["attacks"]

    statement_data =
      Enum.map(statements, fn stmt ->
        rels = Map.get(rel_map, stmt.block.id, [])

        supporting =
          rels
          |> Enum.filter(fn rel ->
            supports_type &&
              rel.type_id == supports_type.id &&
              rel.target_block_id == stmt.block.id
          end)
          |> Enum.map(fn rel ->
            bk = Enum.find(arguments, &(&1.block.id == rel.source_block_id))
            %{rel: rel, bk: bk}
          end)
          |> Enum.reject(&is_nil(&1.bk))

        attacking =
          rels
          |> Enum.filter(fn rel ->
            attacks_type &&
              rel.type_id == attacks_type.id &&
              rel.target_block_id == stmt.block.id
          end)
          |> Enum.map(fn rel ->
            bk = Enum.find(arguments, &(&1.block.id == rel.source_block_id))
            %{rel: rel, bk: bk}
          end)
          |> Enum.reject(&is_nil(&1.bk))

        %{bk: stmt, supporting: supporting, attacking: attacking}
      end)

    linked_ids =
      statement_data
      |> Enum.flat_map(fn s ->
        Enum.map(s.supporting ++ s.attacking, & &1.bk.block.id)
      end)
      |> MapSet.new()

    unlinked = Enum.reject(arguments, &MapSet.member?(linked_ids, &1.block.id))

    %{statements: statement_data, unlinked: unlinked}
  end

  defp apply_search(socket, query) do
    q = String.trim(query) |> String.downcase()

    filtered =
      if q == "" do
        socket.assigns.block_kinds
      else
        Enum.filter(socket.assigns.block_kinds, fn bk ->
          String.contains?(String.downcase(bk.block.block_content.content), q)
        end)
      end

    graph_data = build_graph_data(filtered, socket.assigns.rel_map, socket.assigns.rel_types)

    assign(socket,
      search_query: query,
      filtered_block_kinds: filtered,
      graph_data: graph_data
    )
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

  defp load_voter_map(vote_map, upvote_field, downvote_field) do
    all_ids =
      vote_map
      |> Enum.flat_map(fn {_, fields} ->
        fields
        |> Map.values()
        |> Enum.flat_map(&Metadata.voter_ids/1)
      end)
      |> Enum.uniq()

    users = Wiki.Accounts.get_users_by_ids(all_ids)
    user_by_id = Map.new(users, &{&1.id, &1})

    field_ids =
      [upvote_field && upvote_field.id, downvote_field && downvote_field.id]
      |> Enum.reject(&is_nil/1)

    Map.new(vote_map, fn {block_id, fields} ->
      per_field =
        Map.new(field_ids, fn fid ->
          ids = Metadata.voter_ids(Map.get(fields, fid, %{}))
          {fid, Enum.map(ids, &Map.get(user_by_id, &1)) |> Enum.reject(&is_nil/1)}
        end)

      {block_id, per_field}
    end)
  end

  defp voters_for(block_id, field, voter_map) do
    get_in(voter_map, [block_id, field.id]) || []
  end

  defp argument_blocks(block_kinds), do: Enum.filter(block_kinds, &(&1.kind == "argument"))

  defp filter_argument_blocks(block_kinds, query) do
    args = argument_blocks(block_kinds)

    if String.trim(query) == "" do
      args
    else
      q = String.downcase(query)
      Enum.filter(args, &String.contains?(String.downcase(&1.block.block_content.content), q))
    end
  end

  defp other_block_preview(rel, block_id) do
    other = if rel.source_block_id == block_id, do: rel.target_block, else: rel.source_block
    String.slice(other.block_content.content, 0, 60)
  end

  defp kind_badge_class("argument"), do: "bg-brand-100 text-brand-700"
  defp kind_badge_class("statement"), do: "bg-accent-100 text-accent-700"
  defp kind_badge_class(_), do: "bg-ink-100 text-ink-600"

  defp rel_badge_class("supports"), do: "bg-brand-100 text-brand-700"
  defp rel_badge_class(_), do: "bg-ink-200 text-ink-700"

  defp render_markdown(content) do
    case Earmark.as_html(content) do
      {:ok, html, _} -> {:safe, process_subblock_refs(html)}
      {:error, html, _} -> {:safe, process_subblock_refs(html)}
    end
  end

  defp process_subblock_refs(html) do
    Regex.replace(
      ~r/<a href="sblk:\/\/(sblk_[^"]+)"[^>]*>(.*?)<\/a>/s,
      html,
      ~s(<a href="/subblocks/\\1" class="subblock-ref" title="View highlight">\\2<span class="subblock-ref-icon"> ↗</span></a>)
    )
  end
end
