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
       search_query: ""
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

  defp render_markdown(content) do
    case Earmark.as_html(content) do
      {:ok, html, _} -> {:safe, html}
      {:error, html, _} -> {:safe, html}
    end
  end
end
