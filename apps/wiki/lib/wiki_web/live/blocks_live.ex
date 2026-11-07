defmodule WikiWeb.BlocksLive do
  use WikiWeb, :live_view
  alias Wiki.TextBlock

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       blocks: TextBlock.get_all_blocks(),
       show_editor: false,
       editing_block_id: nil,
       search_query: "",
       text_selection: nil,
       argdown_kind: nil,
       argdown_activities: []
     )}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    blocks =
      query
      |> String.trim()
      |> TextBlock.search_blocks()

    {:noreply, assign(socket, blocks: blocks, search_query: query)}
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
        {:noreply,
         socket
         |> assign(blocks: [block | socket.assigns.blocks], show_editor: false)
         |> put_flash(:info, "Block saved")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save block")}
    end
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
        {:noreply, assign(socket, blocks: Enum.reject(socket.assigns.blocks, &(&1.id == id)))}

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
        {:noreply,
         socket
         |> assign(
           text_selection: nil,
           argdown_kind: nil,
           blocks: [new_block | socket.assigns.blocks]
         )
         |> put_flash(:info, "#{String.capitalize(kind)} added to Deliberation")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(text_selection: nil, argdown_kind: nil)
         |> put_flash(:error, "Failed to create block: #{inspect(reason)}")}
    end
  end

  defp render_markdown(content) do
    case Earmark.as_html(content) do
      {:ok, html, _} -> {:safe, html}
      {:error, html, _} -> {:safe, html}
    end
  end
end
