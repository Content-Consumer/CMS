defmodule Deliberation.Web.VotingActivityLive do
  use WikiWeb, :live_view

  alias Wiki.Metadata

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       activity: nil,
       voting_activity: nil,
       tab: "poll",
       poll_items: [],
       show_editor: false,
       upvote_field: nil,
       downvote_field: nil,
       vote_map: %{},
       voter_map: %{},
       reason_map: %{},
       argument_blocks: [],
       reason_picker_block_id: nil,
       reason_search_query: "",
       link_picker_open: false,
       link_search_query: "",
       breadcrumbs: []
     )}
  end

  @impl true
  def handle_params(%{"activity_id" => activity_id}, _uri, socket) do
    activity = Wiki.Activity.get_group_activity(activity_id)

    socket =
      if activity do
        voting_activity = Deliberation.get_voting_activity(activity_id)
        dim_id = activity.dimension.id

        upvote_field = Metadata.get_field_by_name_in_dimension("upvote", dim_id)
        downvote_field = Metadata.get_field_by_name_in_dimension("downvote", dim_id)

        poll_items = Deliberation.list_poll_items(activity_id)
        va_id = voting_activity && voting_activity.id
        argument_blocks = if va_id, do: Deliberation.list_argument_blocks_for_voting_activity(va_id), else: []

        vote_map = load_vote_map(poll_items, upvote_field, downvote_field)
        voter_map = load_voter_map(vote_map, upvote_field, downvote_field)

        user_id = socket.assigns.current_scope && socket.assigns.current_scope.user && socket.assigns.current_scope.user.id
        block_ids = Enum.map(poll_items, & &1.block.id)
        reason_map = if va_id && user_id && block_ids != [], do: Deliberation.load_vote_reasons(block_ids, va_id, user_id), else: %{}

        scope =
          socket.assigns.current_scope
          |> Wiki.Accounts.Scope.with_dimension(activity.dimension)
          |> Wiki.Accounts.Scope.with_activity(activity)

        assign(socket,
          current_scope: scope,
          activity: activity,
          voting_activity: voting_activity,
          poll_items: poll_items,
          upvote_field: upvote_field,
          downvote_field: downvote_field,
          vote_map: vote_map,
          voter_map: voter_map,
          reason_map: reason_map,
          argument_blocks: argument_blocks,
          page_title: activity.name,
          breadcrumbs: [
            %{label: "Deliberation", path: "/ext/deliberation"},
            %{label: "Poll", path: "/ext/deliberation/poll"},
            %{label: activity.name, path: nil}
          ]
        )
      else
        socket
        |> put_flash(:error, "Activity not found")
        |> push_navigate(to: "/ext/deliberation/poll")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, tab: tab)}
  end

  @impl true
  def handle_event("show_editor", _, socket) do
    {:noreply, assign(socket, show_editor: true)}
  end

  @impl true
  def handle_event("hide_editor", _, socket) do
    {:noreply, assign(socket, show_editor: false)}
  end

  @impl true
  def handle_event("save_poll_item", %{"content" => content}, socket) do
    scope = socket.assigns.current_scope

    if is_nil(scope && scope.user) do
      {:noreply, put_flash(socket, :error, "You must be logged in")}
    else
      case Deliberation.create_poll_item(String.trim(content), socket.assigns.activity.id, scope.user.id) do
          {:ok, {_block, _kind}} ->
            poll_items = Deliberation.list_poll_items(socket.assigns.activity.id)
            {:noreply,
             socket
             |> assign(poll_items: poll_items, show_editor: false)
             |> refresh_vote_data(poll_items)
             |> put_flash(:info, "Poll question added")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to create item: #{inspect(reason)}")}
        end
    end
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
          {:noreply, refresh_vote_data(socket, socket.assigns.poll_items)}

        _ ->
          {:noreply, put_flash(socket, :error, "Failed to register vote")}
      end
    end
  end

  @impl true
  def handle_event("show_reason_picker", %{"block-id" => block_id}, socket) do
    {:noreply, assign(socket, reason_picker_block_id: block_id, reason_search_query: "")}
  end

  @impl true
  def handle_event("hide_reason_picker", _, socket) do
    {:noreply, assign(socket, reason_picker_block_id: nil, reason_search_query: "")}
  end

  @impl true
  def handle_event("search_reason", %{"query" => query}, socket) do
    {:noreply, assign(socket, reason_search_query: query)}
  end

  @impl true
  def handle_event("set_reason", %{"block-id" => block_id, "reason-block-id" => reason_block_id}, socket) do
    scope = socket.assigns.current_scope

    cond do
      is_nil(scope && scope.user) ->
        {:noreply, put_flash(socket, :error, "You must be logged in")}

      is_nil(socket.assigns.voting_activity) ->
        {:noreply, socket}

      true ->
        va_id = socket.assigns.voting_activity.id

        case Deliberation.set_vote_reason(block_id, va_id, scope.user.id, reason_block_id) do
          {:ok, _} ->
            block_ids = Enum.map(socket.assigns.poll_items, & &1.block.id)
            reason_map = Deliberation.load_vote_reasons(block_ids, va_id, scope.user.id)
            {:noreply, assign(socket, reason_map: reason_map, reason_picker_block_id: nil, reason_search_query: "")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to save reason")}
        end
    end
  end

  @impl true
  def handle_event("clear_reason", %{"block-id" => block_id}, socket) do
    scope = socket.assigns.current_scope

    if scope && scope.user && socket.assigns.voting_activity do
      va_id = socket.assigns.voting_activity.id
      Deliberation.clear_vote_reason(block_id, va_id, scope.user.id)
      block_ids = Enum.map(socket.assigns.poll_items, & &1.block.id)
      reason_map = Deliberation.load_vote_reasons(block_ids, va_id, scope.user.id)
      {:noreply, assign(socket, reason_map: reason_map)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_link_picker", _, socket) do
    {:noreply, assign(socket, link_picker_open: true, link_search_query: "")}
  end

  @impl true
  def handle_event("close_link_picker", _, socket) do
    {:noreply, assign(socket, link_picker_open: false, link_search_query: "")}
  end

  @impl true
  def handle_event("search_link", %{"query" => query}, socket) do
    {:noreply, assign(socket, link_search_query: query)}
  end

  @impl true
  def handle_event("link_activity", %{"activity-id" => activity_id}, socket) do
    if socket.assigns.voting_activity do
      va_id = socket.assigns.voting_activity.id

      case Deliberation.link_argument_activity(va_id, activity_id) do
        {:ok, _} ->
          voting_activity = Deliberation.get_voting_activity(socket.assigns.activity.id)
          argument_blocks = Deliberation.list_argument_blocks_for_voting_activity(va_id)
          {:noreply, assign(socket, voting_activity: voting_activity, argument_blocks: argument_blocks, link_picker_open: false)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to link activity")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("unlink_activity", %{"link-id" => link_id}, socket) do
    case Deliberation.unlink_argument_activity(link_id) do
      {:ok, _} ->
        voting_activity = Deliberation.get_voting_activity(socket.assigns.activity.id)
        va_id = socket.assigns.voting_activity.id
        argument_blocks = Deliberation.list_argument_blocks_for_voting_activity(va_id)
        {:noreply, assign(socket, voting_activity: voting_activity, argument_blocks: argument_blocks)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to unlink activity")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} breadcrumbs={@breadcrumbs} current_scope={@current_scope}>
    <div class="max-w-3xl mx-auto px-4 py-8">

      <%!-- Header --%>
      <div class="mb-6">
        <div class="flex items-start justify-between gap-4">
          <div>
            <h1 class="text-2xl font-bold">{@activity.name}</h1>
            <p :if={@voting_activity && @voting_activity.objective} class="mt-1 text-sm opacity-70">
              {@voting_activity.objective}
            </p>
          </div>
          <span class="badge badge-ghost badge-sm shrink-0 mt-1">Voting</span>
        </div>
      </div>

      <%!-- Linked argument activities --%>
      <div class="mb-6 p-4 bg-base-200 rounded-box">
        <div class="flex items-center justify-between mb-2">
          <span class="text-xs font-semibold uppercase tracking-wide opacity-50">Linked Argument Activities</span>
          <button phx-click="open_link_picker" class="btn btn-ghost btn-xs gap-1">
            <.icon name="hero-plus" class="h-3 w-3" /> Link activity
          </button>
        </div>

        <div :if={@voting_activity && @voting_activity.links != []} class="flex flex-wrap gap-2">
          <div :for={link <- (@voting_activity && @voting_activity.links || [])} class="badge badge-outline gap-1 py-3">
            {link.argument_activity.name}
            <button phx-click="unlink_activity" phx-value-link-id={link.id} class="ml-1 opacity-50 hover:opacity-100">
              <.icon name="hero-x-mark" class="h-3 w-3" />
            </button>
          </div>
        </div>
        <p :if={!@voting_activity || @voting_activity.links == []} class="text-xs opacity-40">
          No argument activities linked yet. Link one to allow voters to cite reasons.
        </p>

        <%!-- Link picker --%>
        <div :if={@link_picker_open} class="mt-3 pt-3 border-t border-base-300">
          <form phx-change="search_link" phx-submit="search_link" class="mb-2">
            <input
              type="text"
              name="query"
              value={@link_search_query}
              placeholder="Search argument activities…"
              phx-debounce="150"
              class="input input-sm input-bordered w-full"
              autofocus
            />
          </form>
          <div class="flex flex-col gap-1 max-h-40 overflow-y-auto">
            <button
              :for={act <- filter_linkable_activities(@link_search_query, @voting_activity)}
              phx-click="link_activity"
              phx-value-activity-id={act.id}
              class="btn btn-xs btn-ghost justify-start text-left"
            >
              {act.name}
            </button>
          </div>
          <button phx-click="close_link_picker" class="btn btn-ghost btn-xs mt-2">Cancel</button>
        </div>
      </div>

      <%!-- Tabs --%>
      <div role="tablist" class="tabs tabs-border mb-6">
        <button
          role="tab"
          phx-click="switch_tab"
          phx-value-tab="poll"
          class={"tab #{if @tab == "poll", do: "tab-active"}"}
        >
          Poll
        </button>
        <button
          role="tab"
          phx-click="switch_tab"
          phx-value-tab="results"
          class={"tab #{if @tab == "results", do: "tab-active"}"}
        >
          Results
        </button>
      </div>

      <%!-- Poll tab --%>
      <div :if={@tab == "poll"}>
        <div class="flex justify-end mb-4">
          <button
            :if={!@show_editor && @current_scope && @current_scope.user}
            phx-click="show_editor"
            class="btn btn-primary btn-sm gap-1"
          >
            <.icon name="hero-plus" class="h-4 w-4" /> Add poll question
          </button>
        </div>

        <%!-- Inline editor --%>
        <div :if={@show_editor} class="card bg-base-200 mb-6">
          <div class="card-body">
            <h3 class="font-semibold text-sm mb-2">Add poll question</h3>
            <form phx-submit="save_poll_item">
              <textarea
                name="content"
                placeholder="Enter the question or proposition to vote on…"
                class="textarea textarea-bordered w-full mb-3"
                rows="3"
                autofocus
                required
              ></textarea>
              <div class="flex gap-2 justify-end">
                <button type="button" phx-click="hide_editor" class="btn btn-ghost btn-sm">Cancel</button>
                <button type="submit" class="btn btn-primary btn-sm">Save</button>
              </div>
            </form>
          </div>
        </div>

        <%!-- Poll items --%>
        <div class="space-y-4">
          <div :for={bk <- @poll_items} class="card bg-base-100 border border-base-300 shadow-xs">
            <div class="card-body py-4 px-5">
              <%!-- Block meta --%>
              <div class="flex items-center gap-2 mb-2">
                <span class="badge badge-sm badge-ghost">poll question</span>
                <span :if={bk.created_by} class="text-xs opacity-40 ml-auto">
                  Added by {bk.created_by.email}
                </span>
              </div>

              <%!-- Content --%>
              <div class="text-sm prose prose-sm max-w-none mb-3">
                {render_markdown(bk.block.block_content.content)}
              </div>

              <%!-- Vote buttons --%>
              <div :if={@upvote_field || @downvote_field} class="flex items-center gap-2 pt-3 border-t border-base-200">
                <button
                  :if={@upvote_field && @current_scope && @current_scope.user}
                  phx-click="toggle_vote"
                  phx-value-block-id={bk.block.id}
                  phx-value-field-id={@upvote_field.id}
                  title={voters_for(bk.block.id, @upvote_field, @voter_map) |> Enum.map(& &1.email) |> Enum.join(", ")}
                  class={"btn btn-sm rounded-full border gap-1 #{if voted?(bk.block.id, @upvote_field, @vote_map, @current_scope), do: "border-success text-success font-semibold", else: "btn-ghost border-base-300"}"}
                >
                  <.icon name="hero-hand-thumb-up" class="h-4 w-4 shrink-0" />
                  Agree
                  <span class="opacity-60">{vote_count_for(bk.block.id, @upvote_field, @vote_map)}</span>
                </button>
                <button
                  :if={@downvote_field && @current_scope && @current_scope.user}
                  phx-click="toggle_vote"
                  phx-value-block-id={bk.block.id}
                  phx-value-field-id={@downvote_field.id}
                  title={voters_for(bk.block.id, @downvote_field, @voter_map) |> Enum.map(& &1.email) |> Enum.join(", ")}
                  class={"btn btn-sm rounded-full border gap-1 #{if voted?(bk.block.id, @downvote_field, @vote_map, @current_scope), do: "border-error text-error font-semibold", else: "btn-ghost border-base-300"}"}
                >
                  <.icon name="hero-hand-thumb-down" class="h-4 w-4 shrink-0" />
                  Disagree
                  <span class="opacity-60">{vote_count_for(bk.block.id, @downvote_field, @vote_map)}</span>
                </button>

                <%!-- Reason section --%>
                <div :if={@current_scope && @current_scope.user && has_voted_either?(bk.block.id, @vote_map, @upvote_field, @downvote_field, @current_scope)} class="ml-auto flex items-center gap-2">
                  <span :if={@reason_map[bk.block.id]} class="text-xs opacity-60 max-w-xs truncate">
                    Reason: {reason_preview(@reason_map[bk.block.id])}
                  </span>
                  <button
                    phx-click="show_reason_picker"
                    phx-value-block-id={bk.block.id}
                    class="btn btn-ghost btn-xs gap-1"
                  >
                    <.icon name="hero-chat-bubble-left-ellipsis" class="h-3 w-3" />
                    {if @reason_map[bk.block.id], do: "Change reason", else: "Add reason"}
                  </button>
                  <button
                    :if={@reason_map[bk.block.id]}
                    phx-click="clear_reason"
                    phx-value-block-id={bk.block.id}
                    class="btn btn-ghost btn-xs text-error"
                  >
                    <.icon name="hero-x-mark" class="h-3 w-3" />
                  </button>
                </div>
              </div>

              <%!-- Reason picker --%>
              <div :if={@reason_picker_block_id == bk.block.id} class="mt-3 pt-3 border-t border-base-200">
                <p class="text-xs font-medium opacity-60 mb-2">Pick an opinion from the linked argument activities as your reason:</p>
                <form phx-change="search_reason" phx-submit="search_reason" class="mb-2">
                  <input
                    type="text"
                    name="query"
                    value={@reason_search_query}
                    placeholder="Filter opinions…"
                    phx-debounce="150"
                    class="input input-sm input-bordered w-full"
                    autofocus
                  />
                </form>
                <div :if={filter_argument_blocks(@argument_blocks, @reason_search_query) == [] && @argument_blocks == []} class="text-xs opacity-50 py-2">
                  No argument activities linked. Link one above to cite reasons.
                </div>
                <div :if={filter_argument_blocks(@argument_blocks, @reason_search_query) == [] && @argument_blocks != []} class="text-xs opacity-50 py-2">
                  No opinions match your search.
                </div>
                <div class="flex flex-col gap-1 max-h-56 overflow-y-auto">
                  <button
                    :for={arg <- filter_argument_blocks(@argument_blocks, @reason_search_query)}
                    phx-click="set_reason"
                    phx-value-block-id={bk.block.id}
                    phx-value-reason-block-id={arg.block.id}
                    class="btn btn-xs btn-ghost justify-start text-left h-auto py-2 whitespace-normal"
                  >
                    <span class="opacity-50 mr-1">[{arg.group_activity.name}]</span>
                    {String.slice(arg.block.block_content.content, 0, 80)}
                  </button>
                </div>
                <button phx-click="hide_reason_picker" class="btn btn-ghost btn-xs mt-2">Cancel</button>
              </div>
            </div>
          </div>

          <div :if={@poll_items == []} class="text-center py-16 text-base-content/40">
            No poll questions yet.
            <span :if={Wiki.Accounts.Scope.can_act?(@current_scope)}> Add one above.</span>
          </div>
        </div>
      </div>

      <%!-- Results tab --%>
      <div :if={@tab == "results"} class="text-center py-16 text-base-content/40">
        Results coming soon.
      </div>

    </div>
    </Layouts.app>
    """
  end

  # --- Private helpers ---

  defp opposing_field(field_id, %{upvote_field: up, downvote_field: down}) do
    cond do
      up && up.id == field_id -> down
      down && down.id == field_id -> up
      true -> nil
    end
  end

  defp refresh_vote_data(socket, poll_items) do
    vote_map = load_vote_map(poll_items, socket.assigns.upvote_field, socket.assigns.downvote_field)
    voter_map = load_voter_map(vote_map, socket.assigns.upvote_field, socket.assigns.downvote_field)
    assign(socket, vote_map: vote_map, voter_map: voter_map)
  end

  defp load_vote_map(poll_items, upvote_field, downvote_field) do
    block_ids = Enum.map(poll_items, & &1.block.id)

    field_ids =
      [upvote_field && upvote_field.id, downvote_field && downvote_field.id]
      |> Enum.reject(&is_nil/1)

    if block_ids == [] or field_ids == [], do: %{}, else: Metadata.get_values_for_blocks(block_ids, field_ids)
  end

  defp load_voter_map(vote_map, upvote_field, downvote_field) do
    all_ids =
      vote_map
      |> Enum.flat_map(fn {_, fields} -> Map.values(fields) |> Enum.flat_map(&Metadata.voter_ids/1) end)
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

  defp voted?(block_id, field, vote_map, current_scope) do
    user = current_scope && current_scope.user
    value = get_in(vote_map, [block_id, field.id]) || %{}
    user && Metadata.has_voted?(value, user.id)
  end

  defp vote_count_for(block_id, field, vote_map) do
    value = get_in(vote_map, [block_id, field.id]) || %{}
    Metadata.vote_count(value)
  end

  defp voters_for(block_id, field, voter_map) do
    get_in(voter_map, [block_id, field.id]) || []
  end

  defp has_voted_either?(block_id, vote_map, upvote_field, downvote_field, current_scope) do
    (upvote_field && voted?(block_id, upvote_field, vote_map, current_scope)) ||
      (downvote_field && voted?(block_id, downvote_field, vote_map, current_scope))
  end

  defp reason_preview(%{reason_block: %{block_content: %{content: c}}}), do: String.slice(c, 0, 60)
  defp reason_preview(_), do: ""

  defp filter_argument_blocks(blocks, query) do
    if String.trim(query) == "" do
      blocks
    else
      q = String.downcase(query)
      Enum.filter(blocks, fn bk ->
        String.contains?(String.downcase(bk.block.block_content.content), q)
      end)
    end
  end

  defp filter_linkable_activities(query, voting_activity) do
    linked_ids = if voting_activity, do: Enum.map(voting_activity.links, & &1.argument_activity_id), else: []
    all = Deliberation.list_argument_activities()

    available = Enum.reject(all, &(&1.id in linked_ids))

    if String.trim(query) == "" do
      available
    else
      q = String.downcase(query)
      Enum.filter(available, &String.contains?(String.downcase(&1.name), q))
    end
  end

  defp render_markdown(content) do
    case Earmark.as_html(content) do
      {:ok, html, _} -> {:safe, html}
      {:error, html, _} -> {:safe, html}
    end
  end
end
