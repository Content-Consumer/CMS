defmodule WikiWeb.BlocksLive do
  use WikiWeb, :live_view
  alias Wiki.TextBlock

  @impl true
  def mount(_params, _session, socket) do
    title_field = Wiki.Metadata.get_field_by_name("title")
    blocks = TextBlock.get_all_blocks()

    {:ok,
     socket
     |> assign(
       show_editor: false,
       editing_block_id: nil,
       search_query: "",
       text_selection: nil,
       argdown_kind: nil,
       argdown_activities: [],
       breadcrumbs: [%{label: "Blocks", path: nil}],
       title_field: title_field,
       editing_title_id: nil
     )
     |> put_blocks(blocks)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    blocks = query |> String.trim() |> TextBlock.search_blocks()
    {:noreply, socket |> assign(search_query: query) |> put_blocks(blocks)}
  end

  @impl true
  def handle_event("show_editor", _, socket) do
    {:noreply, assign(socket, show_editor: true, editing_block_id: nil)}
  end

  @impl true
  def handle_event("hide_editor", _, socket) do
    {:noreply, assign(socket, show_editor: false)}
  end

  @impl true
  def handle_event("save_block", %{"content" => content}, socket) do
    case TextBlock.create_block(content) do
      {:ok, block} ->
        new_blocks = [block | socket.assigns.blocks]
        {:noreply,
         socket
         |> put_blocks(new_blocks)
         |> assign(show_editor: false)
         |> put_flash(:info, "Block saved")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save block")}
    end
  end

  @impl true
  def handle_event("edit_block_title", %{"block_id" => block_id}, socket) do
    {:noreply, assign(socket, editing_title_id: block_id)}
  end

  @impl true
  def handle_event("cancel_block_title", _, socket) do
    {:noreply, assign(socket, editing_title_id: nil)}
  end

  @impl true
  def handle_event("save_block_title", %{"block_id" => block_id, "title" => title}, socket) do
    field = socket.assigns.title_field
    title = String.trim(title)

    if field do
      Wiki.Metadata.set_value(block_id, field.id, %{"value" => title})
    end

    title_map = Map.put(socket.assigns.title_map, block_id, if(title == "", do: nil, else: title))
    {:noreply, assign(socket, editing_title_id: nil, title_map: title_map)}
  end

  @impl true
  def handle_event("edit_block", %{"id" => id}, socket) do
    {:noreply, assign(socket, editing_block_id: id, show_editor: false)}
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, editing_block_id: nil)}
  end

  @impl true
  def handle_event("update_block", %{"_id" => id, "content" => content}, socket) do
    case TextBlock.update_block(id, content) do
      {:ok, updated_block} ->
        updated_blocks =
          Enum.map(socket.assigns.blocks, fn b -> if b.id == id, do: updated_block, else: b end)

        {:noreply,
         socket
         |> assign(blocks: updated_blocks, editing_block_id: nil)
         |> put_flash(:info, "Block updated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update block")}
    end
  end

  @impl true
  def handle_event("delete_block", %{"id" => id}, socket) do
    case TextBlock.delete_block(id) do
      {:ok, _} ->
        new_blocks = Enum.reject(socket.assigns.blocks, &(&1.id == id))
        {:noreply, socket |> put_blocks(new_blocks) |> assign(title_map: Map.delete(socket.assigns.title_map, id))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete block")}
    end
  end

  @impl true
  def handle_event("block_extension_action", %{"ext-event" => event, "block-id" => block_id}, socket) do
    # Placeholder: each extension will handle its own events in a future iteration
    {:noreply, put_flash(socket, :info, "#{event} triggered for block #{String.slice(block_id, 0, 8)}…")}
  end

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
    %{block_id: block_id, text: text, from_ix: from_ix, to_ix: to_ix} = socket.assigns.text_selection
    kind = socket.assigns.argdown_kind

    case Deliberation.create_argdown_block(block_id, text, from_ix, to_ix, kind, activity_id) do
      {:ok, {new_block, _block_kind}} ->
        new_blocks = [new_block | socket.assigns.blocks]
        {:noreply,
         socket
         |> put_blocks(new_blocks)
         |> assign(text_selection: nil, argdown_kind: nil)
         |> put_flash(:info, "#{String.capitalize(kind)} added to Deliberation")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(text_selection: nil, argdown_kind: nil)
         |> put_flash(:error, "Failed to create block: #{inspect(reason)}")}
    end
  end

  defp put_blocks(socket, blocks) do
    title_field = socket.assigns[:title_field]
    title_map =
      if title_field && blocks != [] do
        block_ids = Enum.map(blocks, & &1.id)
        raw = Wiki.Metadata.get_values_for_blocks(block_ids, [title_field.id])
        Map.new(block_ids, fn id ->
          title = get_in(raw, [id, title_field.id, "value"])
          {id, if(title == "" or is_nil(title), do: nil, else: title)}
        end)
      else
        %{}
      end

    assign(socket, blocks: blocks, title_map: title_map)
  end

  defp render_markdown(content) do
    case Earmark.as_html(content) do
      {:ok, html, _} -> {:safe, html}
      {:error, html, _} -> {:safe, html}
    end
  end
end
