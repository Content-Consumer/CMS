defmodule WikiWeb.BlockDetailLive do
  use WikiWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       block: nil,
       title: nil,
       subblocks_data: [],
       relations: [],
       extension_sections: [],
       referencing_blocks: [],
       text_selection: nil,
       argdown_kind: nil,
       argdown_activities: [],
       breadcrumbs: []
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    block = Wiki.TextBlock.get_block(id)

    socket =
      if block do
        current_content = block.block_content.content

        raw_subs = Wiki.SubBlock.list_subblocks_for_blocks([id]) |> Map.get(id, [])

        subblocks_data =
          Enum.map(raw_subs, fn s ->
            is_stale =
              is_nil(s.block_content_version) or
                s.block_content_version.content != current_content

            %{id: s.id, from_ix: s.from_ix, to_ix: s.to_ix, text: s.text || "", is_stale: is_stale, is_annotation: is_nil(s.text)}
          end)

        relations = Wiki.BlockRelationship.list_relations_for_block(id)

        title_field = Wiki.Metadata.get_field_by_name("title")

        title =
          if title_field do
            raw = Wiki.Metadata.get_values_for_blocks([id], [title_field.id])
            val = get_in(raw, [id, title_field.id, "value"])
            if val == "" or is_nil(val), do: nil, else: val
          end

        extension_sections = Wiki.Block.Extensions.detail_sections_for(block)

        subblock_ids = Enum.map(raw_subs, & &1.id)
        referencing_blocks = Wiki.SubBlock.find_blocks_referencing_subblocks(subblock_ids)

        display_name = title || (String.slice(id, 0, 12) <> "…")

        assign(socket,
          block: block,
          title: title,
          subblocks_data: subblocks_data,
          relations: relations,
          extension_sections: extension_sections,
          referencing_blocks: referencing_blocks,
          page_title: display_name,
          breadcrumbs: [
            %{label: "Blocks", path: "/blocks"},
            %{label: display_name, path: nil}
          ]
        )
      else
        socket
        |> put_flash(:error, "Block not found")
        |> push_navigate(to: "/blocks")
      end

    {:noreply, socket}
  end

  # --- Component messages ---

  @impl true
  def handle_info({:block_deleted, _id}, socket) do
    {:noreply, push_navigate(socket, to: "/blocks")}
  end

  @impl true
  def handle_info({:block_updated, id}, socket) do
    {:noreply, push_patch(socket, to: "/blocks/#{id}")}
  end

  @impl true
  def handle_info({:put_flash, level, msg}, socket) do
    {:noreply, put_flash(socket, level, msg)}
  end

  @impl true
  def handle_info({:block_extension_action, "deliberation_add_argument", block_id}, socket) do
    block = socket.assigns.block

    if block && block.id == block_id && block.block_content.content != "" do
      content = block.block_content.content
      activities = Deliberation.list_argument_activities()

      {:noreply,
       assign(socket,
         text_selection: %{
           block_id: block_id,
           text: content,
           from_ix: 0,
           to_ix: String.length(content)
         },
         argdown_kind: "argument",
         argdown_activities: activities
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:block_extension_action, _event, _block_id}, socket) do
    {:noreply, socket}
  end

  # --- Text selection / highlight / argdown events ---

  @impl true
  def handle_event("text_selected", %{"block_id" => block_id, "text" => text, "from_ix" => from_ix, "to_ix" => to_ix}, socket) do
    activities = Deliberation.list_argument_activities()

    {:noreply,
     assign(socket,
       text_selection: %{block_id: block_id, text: text, from_ix: from_ix, to_ix: to_ix},
       argdown_kind: nil,
       argdown_activities: activities
     )}
  end

  @impl true
  def handle_event("argdown_dismiss", _params, socket) do
    {:noreply, assign(socket, text_selection: nil, argdown_kind: nil)}
  end

  @impl true
  def handle_event("argdown_select_kind", %{"kind" => kind}, socket) do
    {:noreply, assign(socket, argdown_kind: kind)}
  end

  @impl true
  def handle_event("argdown_create", %{"activity_id" => activity_id}, socket) do
    base_scope = socket.assigns.current_scope
    activity = Wiki.Activity.get_group_activity(activity_id)

    scope =
      with %Wiki.Accounts.Scope{} <- base_scope,
           %Wiki.Activity.GroupActivity{} <- activity do
        base_scope
        |> Wiki.Accounts.Scope.with_dimension(activity.dimension)
        |> Wiki.Accounts.Scope.with_activity(activity)
      else
        _ -> base_scope
      end

    cond do
      is_nil(base_scope && base_scope.user) ->
        {:noreply, put_flash(socket, :error, "You must be logged in")}

      is_nil(activity) ->
        {:noreply, put_flash(socket, :error, "Activity not found")}

      true ->
        %{block_id: block_id, text: text, from_ix: from_ix, to_ix: to_ix} = socket.assigns.text_selection
        kind = socket.assigns.argdown_kind

        case Deliberation.create_argdown_block(block_id, text, from_ix, to_ix, kind, activity_id, scope.user.id) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(text_selection: nil, argdown_kind: nil)
             |> push_patch(to: "/blocks/#{block_id}")
             |> put_flash(:info, "#{String.capitalize(kind)} added to Deliberation")}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(text_selection: nil, argdown_kind: nil)
             |> put_flash(:error, "Failed to create block: #{inspect(reason)}")}
        end
    end
  end

  @impl true
  def handle_event("create_highlight", _, socket) do
    case socket.assigns.text_selection do
      nil ->
        {:noreply, socket}

      %{block_id: block_id, text: text, from_ix: from_ix, to_ix: to_ix} ->
        user_id = socket.assigns.current_scope && socket.assigns.current_scope.user && socket.assigns.current_scope.user.id

        case Wiki.SubBlock.create_subblock(block_id, from_ix, to_ix, text, user_id) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(text_selection: nil)
             |> push_patch(to: "/blocks/#{block_id}")
             |> put_flash(:info, "Highlight created")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to create highlight")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} breadcrumbs={@breadcrumbs} current_scope={@current_scope}>
      <div class="max-w-3xl mx-auto px-4 py-8">

        <%!-- Page header --%>
        <div class="mb-4">
          <h1 :if={@title} class="text-2xl font-bold mb-1">{@title}</h1>
          <code class="text-xs opacity-30">{@block.id}</code>
        </div>

        <%!-- Block card — full functionality via component --%>
        <div class="mb-6">
          <.live_component
            module={WikiWeb.BlockCardLive}
            id={@block.id}
            block={@block}
            current_scope={@current_scope}
            subblocks={@subblocks_data}
          />
        </div>

        <%!-- Highlights --%>
        <div :if={Enum.any?(@subblocks_data, &(!&1.is_annotation))} class="mb-6">
          <h2 class="text-xs font-semibold opacity-50 uppercase tracking-widest mb-3">
            Highlights ({Enum.count(@subblocks_data, &(!&1.is_annotation))})
          </h2>
          <div class="space-y-1">
            <.link
              :for={sub <- Enum.reject(@subblocks_data, & &1.is_annotation)}
              href={"/subblocks/#{sub.id}"}
              class="flex items-center gap-2 text-sm px-3 py-2 rounded-box hover:bg-base-200"
            >
              <code class="text-xs opacity-40 shrink-0">{String.slice(sub.id, 0, 14)}…</code>
              <span class="truncate opacity-70 flex-1">{sub.text}</span>
              <span :if={sub.is_stale} class="badge badge-xs badge-warning shrink-0">stale</span>
            </.link>
          </div>
        </div>

        <%!-- Relationships --%>
        <div :if={@relations != []} class="mb-6">
          <h2 class="text-xs font-semibold opacity-50 uppercase tracking-widest mb-3">
            Relationships ({length(@relations)})
          </h2>
          <div class="space-y-1">
            <.link
              :for={rel <- @relations}
              href={"/blocks/#{other_block_id(rel, @block.id)}"}
              class="flex items-center gap-2 text-sm px-3 py-2 rounded-box hover:bg-base-200"
            >
              <span class="badge badge-xs badge-ghost shrink-0">{rel.type.label}</span>
              <span class="truncate opacity-70 flex-1">{other_block_preview(rel, @block.id)}</span>
            </.link>
          </div>
        </div>

        <%!-- Extension sections (e.g. Activity Memberships from Deliberation) --%>
        <div :for={section <- @extension_sections} class="mb-6">
          <h2 class="text-xs font-semibold opacity-50 uppercase tracking-widest mb-3">
            {section.title} ({length(section.items)})
          </h2>
          <div class="space-y-1">
            <.link
              :for={item <- section.items}
              href={item.href}
              class="flex items-center gap-2 text-sm px-3 py-2 rounded-box hover:bg-base-200"
            >
              <span :if={item[:badge]} class="badge badge-xs badge-primary shrink-0">{item.badge}</span>
              <span class="opacity-70">{item.label}</span>
            </.link>
          </div>
        </div>

        <%!-- Blocks that paste-reference a highlight from this block --%>
        <div :if={@referencing_blocks != []} class="mb-6">
          <h2 class="text-xs font-semibold opacity-50 uppercase tracking-widest mb-3">
            Referenced in ({length(@referencing_blocks)})
          </h2>
          <div class="space-y-1">
            <.link
              :for={b <- @referencing_blocks}
              href={"/blocks/#{b.id}"}
              class="flex items-center gap-2 text-sm px-3 py-2 rounded-box hover:bg-base-200"
            >
              <code class="text-xs opacity-40 shrink-0">{String.slice(b.id, 0, 8)}…</code>
              <span class="truncate opacity-70 flex-1">
                {String.slice(b.block_content.content, 0, 80)}
              </span>
            </.link>
          </div>
        </div>
      </div>

      <%!-- Selection popover (highlight / add argument) --%>
      <div
        :if={@text_selection != nil}
        id="detail-argdown-popover"
        class="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 w-full max-w-lg px-4"
      >
        <div class="rounded-box border border-base-300 bg-base-100 shadow-lg p-4 text-sm">
          <div :if={is_nil(@argdown_kind)}>
            <p class="text-xs font-medium opacity-60 mb-3">
              "<span class="italic">{@text_selection.text}</span>"
            </p>
            <div class="flex flex-col gap-3">
              <div>
                <button phx-click="create_highlight" class="btn btn-sm btn-outline">
                  Highlight
                </button>
              </div>
              <div class="border-t border-base-200 pt-3">
                <p class="text-xs opacity-40 mb-2">Deliberation</p>
                <div class="flex gap-2">
                  <button
                    phx-click="argdown_select_kind"
                    phx-value-kind="argument"
                    class="btn btn-sm btn-outline"
                  >
                    Add argument
                  </button>
                </div>
              </div>
              <div class="border-t border-base-200 pt-3">
                <button phx-click="argdown_dismiss" class="btn btn-sm btn-ghost">Cancel</button>
              </div>
            </div>
          </div>

          <div :if={not is_nil(@argdown_kind)}>
            <p class="text-xs font-medium opacity-60 mb-3">
              Add as <strong>{@argdown_kind}</strong> to which activity?
            </p>
            <div :if={@argdown_activities == []} class="text-xs opacity-50 mb-2">
              No argument activities yet.
              <.link href="/ext/deliberation/argument/new" class="link">Create one</.link> first.
            </div>
            <div class="flex flex-col gap-1 mb-2">
              <button
                :for={activity <- @argdown_activities}
                phx-click="argdown_create"
                phx-value-activity_id={activity.id}
                class="btn btn-sm btn-outline justify-start"
              >
                {activity.name}
              </button>
            </div>
            <button phx-click="argdown_dismiss" class="btn btn-sm btn-ghost">Cancel</button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp other_block_id(rel, block_id) do
    if rel.source_block_id == block_id, do: rel.target_block_id, else: rel.source_block_id
  end

  defp other_block_preview(rel, block_id) do
    other = if rel.source_block_id == block_id, do: rel.target_block, else: rel.source_block
    String.slice(other.block_content.content, 0, 80)
  end
end
