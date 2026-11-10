defmodule WikiWeb.BlockCardLive do
  use WikiWeb, :live_component

  alias Wiki.{TextBlock, Metadata, BlockRelationship}

  slot :extra

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       editing: false,
       editing_title: false,
       editing_ref: false,
       ref_search_query: "",
       ref_suggestions: [],
       title: nil,
       url: nil,
       refs: [],
       title_field: nil,
       url_field: nil,
       ref_type: nil,
       is_owner: false,
       data_loaded: false,
       subblocks: [],
       ext_items: [],
       is_long: false,
       collapsed: false
     )}
  end

  @impl true
  def update(assigns, socket) do
    block = assigns.block
    prev_block = socket.assigns[:block]

    # Carry over all parent assigns except :block — we manage block ourselves
    # after first load so the parent can't overwrite our preloaded associations.
    socket = assign(socket, Map.drop(assigns, [:block]))
    socket = assign(socket, is_owner: is_owner?(assigns[:current_scope], block))

    needs_load = !socket.assigns.data_loaded || is_nil(prev_block) || prev_block.id != block.id

    if needs_load do
      {:ok, socket |> assign(block: block) |> load_block_data(block)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("toggle_collapsed", _, socket) do
    {:noreply, assign(socket, collapsed: !socket.assigns.collapsed)}
  end

  @impl true
  def handle_event("edit", _, socket) do
    if socket.assigns.is_owner, do: {:noreply, assign(socket, editing: true)}, else: {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, editing: false)}
  end

  @impl true
  def handle_event("save", %{"content" => content}, socket) do
    block = socket.assigns.block

    if not socket.assigns.is_owner do
      {:noreply, socket}
    else
      case TextBlock.update_block(block.id, content) do
        {:ok, updated_block} ->
          send(self(), {:block_updated, block.id})
          {:noreply, assign(socket, block: updated_block, editing: false)}

        {:error, _} ->
          send(self(), {:put_flash, :error, "Failed to update block"})
          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("delete", _, socket) do
    block = socket.assigns.block

    if not socket.assigns.is_owner do
      {:noreply, socket}
    else
      case TextBlock.delete_block(block.id) do
        {:ok, _} ->
          send(self(), {:block_deleted, block.id})
          {:noreply, socket}

        {:error, _} ->
          send(self(), {:put_flash, :error, "Failed to delete block"})
          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("edit_title", _, socket) do
    if socket.assigns.is_owner, do: {:noreply, assign(socket, editing_title: true)}, else: {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_title", _, socket) do
    {:noreply, assign(socket, editing_title: false)}
  end

  @impl true
  def handle_event("save_title", %{"title" => title}, socket) do
    field = socket.assigns.title_field
    block = socket.assigns.block
    title = String.trim(title)

    if field do
      Metadata.set_value(block.id, field.id, %{"value" => title})
    end

    {:noreply, assign(socket, title: (if title == "", do: nil, else: title), editing_title: false)}
  end

  @impl true
  def handle_event("show_ref_editor", _, socket) do
    ref_type = BlockRelationship.get_type_by_name("references")
    {:noreply, assign(socket, editing_ref: true, ref_type: ref_type, ref_search_query: "", ref_suggestions: [])}
  end

  @impl true
  def handle_event("hide_ref_editor", _, socket) do
    {:noreply, assign(socket, editing_ref: false, ref_type: nil, ref_search_query: "", ref_suggestions: [])}
  end

  @impl true
  def handle_event("search_ref", %{"query" => query}, socket) do
    suggestions =
      query
      |> String.trim()
      |> TextBlock.search_blocks()
      |> Enum.reject(&(&1.id == socket.assigns.block.id))

    {:noreply, assign(socket, ref_search_query: query, ref_suggestions: suggestions)}
  end

  @impl true
  def handle_event("create_reference", %{"target_id" => target_id}, socket) do
    source_id = socket.assigns.block.id
    ref_type = socket.assigns.ref_type

    case BlockRelationship.create_relation(source_id, target_id, ref_type.id) do
      {:ok, _} ->
        refs = load_refs(source_id)
        send(self(), {:block_updated, source_id})

        {:noreply,
         assign(socket,
           refs: refs,
           editing_ref: false,
           ref_type: nil,
           ref_search_query: "",
           ref_suggestions: []
         )}

      {:error, _} ->
        send(self(), {:put_flash, :error, "Failed to add reference"})
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_relation", %{"id" => id}, socket) do
    case BlockRelationship.delete_relation(id) do
      {:ok, _} ->
        refs = load_refs(socket.assigns.block.id)
        {:noreply, assign(socket, refs: refs)}

      {:error, _} ->
        send(self(), {:put_flash, :error, "Failed to remove relation"})
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("block_extension_action", %{"ext-event" => event, "block-id" => block_id}, socket) do
    send(self(), {:block_extension_action, event, block_id})
    {:noreply, socket}
  end

  defp load_block_data(socket, block) do
    title_field = Metadata.get_field_by_name("title")
    url_field = Metadata.get_field_by_name("url")

    field_ids =
      [title_field && title_field.id, url_field && url_field.id]
      |> Enum.reject(&is_nil/1)

    {title, url} =
      if field_ids != [] do
        raw = Metadata.get_values_for_blocks([block.id], field_ids)

        title =
          if title_field do
            val = get_in(raw, [block.id, title_field.id, "value"])
            if val == "" or is_nil(val), do: nil, else: val
          end

        url =
          if url_field do
            val = get_in(raw, [block.id, url_field.id, "value"])
            if val == "" or is_nil(val), do: nil, else: val
          end

        {title, url}
      else
        {nil, nil}
      end

    block = Wiki.Repo.preload(block, :created_by)

    word_count = block.block_content.content |> String.split() |> length()
    is_long = word_count > 100

    assign(socket,
      block: block,
      title: title,
      url: url,
      refs: load_refs(block.id),
      title_field: title_field,
      url_field: url_field,
      ext_items: load_ext_items(block),
      is_long: is_long,
      collapsed: is_long,
      data_loaded: true
    )
  end

  defp load_ext_items(block) do
    block
    |> Wiki.Block.Extensions.options_for()
    |> Enum.flat_map(fn {_ext_name, opts} -> opts end)
    |> Enum.group_by(& &1.section)
    |> Enum.flat_map(fn {section, opts} ->
      header = if section, do: [{:header, section}], else: []
      header ++ Enum.map(opts, &{:action, &1})
    end)
  end

  defp load_refs(block_id) do
    block_id
    |> BlockRelationship.list_relations_for_block()
    |> Enum.filter(&(&1.type && &1.type.name == "references"))
  end

  defp is_owner?(scope, block) do
    not is_nil(scope && scope.user) && scope.user.id == block.created_by_id
  end

  defp format_timestamp(%DateTime{} = dt) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, dt, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      diff < 86_400 * 7 -> "#{div(diff, 86_400)}d ago"
      true ->
        "#{dt.day} #{month_abbr(dt.month)} #{dt.year}"
    end
  end

  defp format_timestamp(%NaiveDateTime{} = ndt) do
    ndt |> DateTime.from_naive!("Etc/UTC") |> format_timestamp()
  end

  defp month_abbr(m) do
    ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec) |> Enum.at(m - 1)
  end

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

  defp other_block_content(rel, block_id) do
    other = if rel.source_block_id == block_id, do: rel.target_block, else: rel.source_block
    String.slice(other.block_content.content, 0, 60)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 shadow-xs">
      <%!-- Edit mode --%>
      <div :if={@editing} class="card-body">
        <form phx-submit="save" phx-target={@myself}>
          <div id={"tiptap-wrapper-card-#{@id}"} phx-update="ignore">
            <div
              id={"tiptap-editor-card-#{@id}"}
              phx-hook="TiptapEditor"
              data-input-id={"block-content-card-#{@id}"}
              class="tiptap-editor bg-base-50 rounded-box border border-base-300 p-4 min-h-32 cursor-text"
            >
            </div>
          </div>
          <input
            type="hidden"
            name="content"
            id={"block-content-card-#{@id}"}
            value={@block.block_content.content}
          />
          <div class="card-actions justify-end mt-4">
            <button type="button" phx-click="cancel_edit" phx-target={@myself} class="btn btn-ghost btn-sm">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary btn-sm">Save</button>
          </div>
        </form>
      </div>
      <%!-- Preview mode --%>
      <div :if={!@editing} class="card-body py-4 px-5">
        <div class="flex items-center justify-between mb-2">
          <div class="flex items-center gap-2 flex-wrap">
            <span :if={@block.created_by && @block.created_by.username} class="text-xs opacity-40">
              @{@block.created_by.username}
            </span>
            <.link href={"/blocks/#{@block.id}"} class="text-xs opacity-40 hover:opacity-70 hover:underline">
              {format_timestamp(@block.inserted_at)}
            </.link>
            <a
              :if={@url}
              href={@url}
              target="_blank"
              rel="noopener noreferrer"
              class="text-xs opacity-50 hover:opacity-80 flex items-center gap-1 max-w-48 truncate"
              title={@url}
            >
              <.icon name="hero-link" class="h-3 w-3 shrink-0" />
              {URI.parse(@url).host || @url}
            </a>
          </div>
          <div class="flex items-center gap-1">
            <button
              :if={@is_owner}
              phx-click="edit"
              phx-target={@myself}
              class="btn btn-ghost btn-xs"
              title="Edit"
            >
              <.icon name="hero-pencil-square" class="h-4 w-4" />
            </button>
            <button
              :if={@is_owner}
              phx-click="delete"
              phx-target={@myself}
              class="btn btn-ghost btn-xs text-error"
              title="Delete"
            >
              <.icon name="hero-trash" class="h-4 w-4" />
            </button>
            <div class="dropdown dropdown-end">
              <button tabindex="0" class="btn btn-ghost btn-xs" title="More options">
                <.icon name="hero-ellipsis-vertical" class="h-4 w-4" />
              </button>
              <ul
                tabindex="0"
                class="dropdown-content menu bg-base-100 rounded-box z-10 w-52 p-1 shadow-md border border-base-300 text-sm"
              >
                <li :if={@is_owner}>
                  <button
                    phx-click="edit_title"
                    phx-target={@myself}
                    class="flex items-center gap-2 w-full"
                  >
                    <.icon name="hero-tag" class="h-4 w-4 shrink-0" />
                    {if @title, do: "Edit title", else: "Set title"}
                  </button>
                </li>
                <li>
                  <button
                    phx-click="show_ref_editor"
                    phx-target={@myself}
                    class="flex items-center gap-2 w-full"
                  >
                    <.icon name="hero-link" class="h-4 w-4 shrink-0" />
                    Add reference
                  </button>
                </li>
                <%!-- Extension sections --%>
                <li :if={@ext_items != []}>
                  <hr class="border-base-200 -mx-1 my-0.5" />
                </li>
                <li :for={{type, item} <- @ext_items}>
                  <span
                    :if={type == :header}
                    class="text-xs font-semibold uppercase tracking-wide opacity-40 pointer-events-none block px-1 py-0.5"
                  >{item}</span>
                  <button
                    :if={type == :action}
                    phx-click="block_extension_action"
                    phx-value-ext-event={item.event}
                    phx-value-block-id={item.block_id}
                    phx-target={@myself}
                    class="flex items-center gap-2 w-full"
                  >
                    <.icon :if={item.icon} name={item.icon} class="h-4 w-4 shrink-0" />
                    {item.label}
                  </button>
                </li>
              </ul>
            </div>
          </div>
        </div>
        <%!-- Inline title editor --%>
        <form
          :if={@editing_title}
          phx-submit="save_title"
          phx-target={@myself}
          class="flex gap-2 mb-3"
        >
          <input
            type="text"
            name="title"
            value={@title || ""}
            placeholder="Enter a title…"
            class="input input-sm input-bordered flex-1"
            autofocus
          />
          <button type="submit" class="btn btn-primary btn-sm">Save</button>
          <button type="button" phx-click="cancel_title" phx-target={@myself} class="btn btn-ghost btn-sm">
            Cancel
          </button>
        </form>
        <%!-- Title display --%>
        <p :if={@title && !@editing_title} class="font-semibold text-base mb-1">
          {@title}
        </p>
        <%!-- Content --%>
        <div class={["relative", @collapsed && "max-h-32 overflow-hidden"]}>
          <div
            id={"argdown-#{@block.id}"}
            phx-hook="ArgdownSelector"
            data-block-id={@block.id}
            data-subblocks={Jason.encode!(@subblocks)}
            class="block-preview text-sm"
          >
            {render_markdown(@block.block_content.content)}
          </div>
          <div
            :if={@collapsed}
            class="absolute bottom-0 left-0 right-0 h-12 bg-gradient-to-t from-base-100 to-transparent pointer-events-none"
          ></div>
        </div>
        <button
          :if={@is_long}
          phx-click="toggle_collapsed"
          phx-target={@myself}
          class="btn btn-ghost btn-xs mt-1 text-xs opacity-50 hover:opacity-80"
        >
          {if @collapsed, do: "Show more", else: "Show less"}
        </button>
        <%!-- Extra slot (deliberation-specific: votes, relationship buttons, etc.) --%>
        {render_slot(assigns[:extra] || [])}
        <%!-- Inline reference editor --%>
        <div :if={@editing_ref} class="mt-3 pt-3 border-t border-base-200">
          <p class="text-xs font-medium opacity-60 mb-2">Search for a block to reference:</p>
          <form phx-change="search_ref" phx-submit="search_ref" phx-target={@myself}>
            <input
              type="text"
              name="query"
              value={@ref_search_query}
              placeholder="Type to search…"
              phx-debounce="200"
              class="input input-sm input-bordered w-full"
              autofocus
            />
          </form>
          <ul :if={@ref_suggestions != []} class="mt-2 space-y-1">
            <li :for={suggestion <- @ref_suggestions}>
              <button
                phx-click="create_reference"
                phx-value-target_id={suggestion.id}
                phx-target={@myself}
                class="w-full text-left text-xs px-3 py-2 rounded-box hover:bg-base-200 truncate"
              >
                <span class="opacity-40 mr-1 font-mono">{String.slice(suggestion.id, 0, 8)}…</span>
                {String.slice(suggestion.block_content.content, 0, 80)}
              </button>
            </li>
          </ul>
          <div :if={@ref_search_query != "" and @ref_suggestions == []} class="mt-2 text-xs opacity-50">
            No blocks found.
          </div>
          <button phx-click="hide_ref_editor" phx-target={@myself} class="btn btn-ghost btn-xs mt-2">
            Cancel
          </button>
        </div>
        <%!-- References list --%>
        <div :if={@refs != []} class="mt-3 pt-3 border-t border-base-200">
          <p class="text-xs font-medium opacity-60 mb-2">References</p>
          <ul class="space-y-1">
            <li :for={rel <- @refs} class="flex items-center gap-2 text-xs">
              <.icon name="hero-link" class="h-3 w-3 opacity-40 shrink-0" />
              <span class="opacity-60 font-mono truncate flex-1">
                {other_block_content(rel, @block.id)}
              </span>
              <button
                phx-click="delete_relation"
                phx-value-id={rel.id}
                phx-target={@myself}
                class="btn btn-ghost btn-xs text-error"
                title="Remove"
              >
                <.icon name="hero-x-mark" class="h-3 w-3" />
              </button>
            </li>
          </ul>
        </div>
      </div>
    </div>
    """
  end
end
