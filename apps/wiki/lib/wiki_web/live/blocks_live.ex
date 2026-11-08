defmodule WikiWeb.BlocksLive do
  use WikiWeb, :live_view
  alias Wiki.TextBlock

  @impl true
  def mount(_params, _session, socket) do
    title_field = Wiki.Metadata.get_field_by_name("title")
    url_field = Wiki.Metadata.get_field_by_name("url")
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
       url_field: url_field,
       editing_title_id: nil,
       ref_type: nil,
       editing_ref_id: nil,
       ref_search_query: "",
       ref_suggestions: [],
       rel_map: %{},
       subblock_map: %{},
       new_block_type: nil,
       webpage_url: "",
       webpage_fetching: false,
       webpage_draft: nil
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
    {:noreply, assign(socket, show_editor: true, editing_block_id: nil, new_block_type: nil)}
  end

  @impl true
  def handle_event("hide_editor", _, socket) do
    {:noreply, assign(socket, show_editor: false)}
  end

  @impl true
  def handle_event("show_webpage_editor", _, socket) do
    {:noreply, assign(socket, new_block_type: :webpage, show_editor: false, webpage_url: "", webpage_draft: nil, webpage_fetching: false)}
  end

  @impl true
  def handle_event("cancel_webpage", _, socket) do
    {:noreply, assign(socket, new_block_type: nil, webpage_url: "", webpage_draft: nil, webpage_fetching: false)}
  end

  @impl true
  def handle_event("fetch_webpage", %{"url" => url}, socket) do
    url = String.trim(url)
    pid = self()
    Task.start(fn -> send(pid, {:webpage_fetched, Wiki.WebPage.fetch_and_extract(url)}) end)
    {:noreply, assign(socket, webpage_fetching: true, webpage_url: url)}
  end

  @impl true
  def handle_info({:webpage_fetched, {:ok, draft}}, socket) do
    {:noreply, assign(socket, webpage_draft: draft, webpage_fetching: false)}
  end

  @impl true
  def handle_info({:webpage_fetched, {:error, reason}}, socket) do
    {:noreply, socket |> assign(webpage_fetching: false) |> put_flash(:error, "Import failed: #{reason}")}
  end

  @impl true
  def handle_event("save_webpage_block", %{"content" => content, "url" => url, "title" => title}, socket) do
    user_id = socket.assigns.current_scope && socket.assigns.current_scope.user && socket.assigns.current_scope.user.id

    case TextBlock.create_block(content, user_id) do
      {:ok, block} ->
        title_field = socket.assigns.title_field
        url_field = socket.assigns.url_field

        if title_field && String.trim(title) != "" do
          Wiki.Metadata.set_value(block.id, title_field.id, %{"value" => String.trim(title)})
        end

        if url_field && String.trim(url) != "" do
          Wiki.Metadata.set_value(block.id, url_field.id, %{"value" => String.trim(url)})
        end

        new_blocks = [block | socket.assigns.blocks]
        {:noreply,
         socket
         |> put_blocks(new_blocks)
         |> assign(new_block_type: nil, webpage_draft: nil, webpage_url: "")
         |> put_flash(:info, "Web page imported")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save block")}
    end
  end

  @impl true
  def handle_event("save_block", %{"content" => content}, socket) do
    user_id = socket.assigns.current_scope && socket.assigns.current_scope.user.id
    case TextBlock.create_block(content, user_id) do
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
    if owns_block?(socket, block_id) do
      {:noreply, assign(socket, editing_title_id: block_id)}
    else
      {:noreply, put_flash(socket, :error, "You can only edit blocks you created")}
    end
  end

  @impl true
  def handle_event("cancel_block_title", _, socket) do
    {:noreply, assign(socket, editing_title_id: nil)}
  end

  @impl true
  def handle_event("save_block_title", %{"block_id" => block_id, "title" => title}, socket) do
    if not owns_block?(socket, block_id) do
      {:noreply, put_flash(socket, :error, "You can only edit blocks you created")}
    else
      field = socket.assigns.title_field
      title = String.trim(title)

      if field do
        Wiki.Metadata.set_value(block_id, field.id, %{"value" => title})
      end

      title_map = Map.put(socket.assigns.title_map, block_id, if(title == "", do: nil, else: title))
      {:noreply, assign(socket, editing_title_id: nil, title_map: title_map)}
    end
  end

  @impl true
  def handle_event("edit_block", %{"id" => id}, socket) do
    if owns_block?(socket, id) do
      {:noreply, assign(socket, editing_block_id: id, show_editor: false)}
    else
      {:noreply, put_flash(socket, :error, "You can only edit blocks you created")}
    end
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, editing_block_id: nil)}
  end

  @impl true
  def handle_event("update_block", %{"_id" => id, "content" => content}, socket) do
    if not owns_block?(socket, id) do
      {:noreply, put_flash(socket, :error, "You can only edit blocks you created")}
    else
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
  end

  @impl true
  def handle_event("delete_block", %{"id" => id}, socket) do
    if not owns_block?(socket, id) do
      {:noreply, put_flash(socket, :error, "You can only delete blocks you created")}
    else
      case TextBlock.delete_block(id) do
        {:ok, _} ->
          new_blocks = Enum.reject(socket.assigns.blocks, &(&1.id == id))
          {:noreply, socket |> put_blocks(new_blocks) |> assign(title_map: Map.delete(socket.assigns.title_map, id))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete block")}
      end
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
  end

  @impl true
  def handle_event("create_highlight", _, socket) do
    case socket.assigns.text_selection do
      nil ->
        {:noreply, socket}

      %{block_id: block_id, text: text, from_ix: from_ix, to_ix: to_ix} ->
        user_id = socket.assigns.current_scope && socket.assigns.current_scope.user.id
        case Wiki.SubBlock.create_subblock(block_id, from_ix, to_ix, text, user_id) do
          {:ok, _subblock} ->
            {:noreply,
             socket
             |> put_blocks(socket.assigns.blocks)
             |> assign(text_selection: nil)
             |> put_flash(:info, "Highlight created")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to create highlight")}
        end
    end
  end

  @impl true
  def handle_event("get_subblock_text", %{"id" => id}, socket) do
    text =
      case Wiki.SubBlock.get_subblock(id) do
        nil -> nil
        sub -> sub.text
      end

    {:reply, %{text: text, id: id}, socket}
  end

  @impl true
  def handle_event("show_ref_editor", %{"id" => id}, socket) do
    ref_type = Wiki.BlockRelationship.get_type_by_name("references")
    {:noreply, assign(socket, editing_ref_id: id, ref_type: ref_type, ref_search_query: "", ref_suggestions: [])}
  end

  @impl true
  def handle_event("hide_ref_editor", _, socket) do
    {:noreply, assign(socket, editing_ref_id: nil, ref_type: nil, ref_search_query: "", ref_suggestions: [])}
  end

  @impl true
  def handle_event("search_ref", %{"query" => query}, socket) do
    suggestions =
      query
      |> String.trim()
      |> Wiki.TextBlock.search_blocks()
      |> Enum.reject(fn b -> b.id == socket.assigns.editing_ref_id end)
    {:noreply, assign(socket, ref_search_query: query, ref_suggestions: suggestions)}
  end

  @impl true
  def handle_event("create_reference", %{"target_id" => target_id}, socket) do
    source_id = socket.assigns.editing_ref_id
    ref_type = socket.assigns.ref_type

    case Wiki.BlockRelationship.create_relation(source_id, target_id, ref_type.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_blocks(socket.assigns.blocks)
         |> assign(editing_ref_id: nil, ref_type: nil, ref_search_query: "", ref_suggestions: [])
         |> put_flash(:info, "Reference added")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add reference")}
    end
  end

  @impl true
  def handle_event("delete_relation", %{"id" => id}, socket) do
    case Wiki.BlockRelationship.delete_relation(id) do
      {:ok, _} ->
        {:noreply, socket |> put_blocks(socket.assigns.blocks) |> put_flash(:info, "Relation removed")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove relation")}
    end
  end

  defp other_block_content(rel, block_id) do
    other = if rel.source_block_id == block_id, do: rel.target_block, else: rel.source_block
    String.slice(other.block_content.content, 0, 60)
  end

  defp put_blocks(socket, blocks) do
    title_field = socket.assigns[:title_field]
    url_field = socket.assigns[:url_field]

    field_ids =
      [title_field && title_field.id, url_field && url_field.id]
      |> Enum.reject(&is_nil/1)

    raw_meta =
      if field_ids != [] && blocks != [] do
        block_ids = Enum.map(blocks, & &1.id)
        Wiki.Metadata.get_values_for_blocks(block_ids, field_ids)
      else
        %{}
      end

    block_ids = Enum.map(blocks, & &1.id)

    title_map =
      if title_field do
        Map.new(block_ids, fn id ->
          val = get_in(raw_meta, [id, title_field.id, "value"])
          {id, if(val == "" or is_nil(val), do: nil, else: val)}
        end)
      else
        %{}
      end

    url_map =
      if url_field do
        Map.new(block_ids, fn id ->
          val = get_in(raw_meta, [id, url_field.id, "value"])
          {id, if(val == "" or is_nil(val), do: nil, else: val)}
        end)
      else
        %{}
      end

    rel_map =
      if blocks != [] do
        block_ids = Enum.map(blocks, & &1.id)
        Wiki.BlockRelationship.list_relations_for_blocks(block_ids)
      else
        %{}
      end

    subblock_map =
      if blocks != [] do
        block_ids = Enum.map(blocks, & &1.id)
        raw = Wiki.SubBlock.list_subblocks_for_blocks(block_ids)

        Map.new(block_ids, fn id ->
          block = Enum.find(blocks, &(&1.id == id))
          current_content = block.block_content.content
          subs = Map.get(raw, id, [])

          sub_data =
            Enum.map(subs, fn s ->
              is_stale =
                is_nil(s.block_content_version) or
                  s.block_content_version.content != current_content

              %{id: s.id, from_ix: s.from_ix, to_ix: s.to_ix, text: s.text || "", is_stale: is_stale}
            end)

          {id, sub_data}
        end)
      else
        %{}
      end

    assign(socket, blocks: blocks, title_map: title_map, url_map: url_map, rel_map: rel_map, subblock_map: subblock_map)
  end

  defp owns_block?(socket, block_id) do
    user_id = socket.assigns.current_scope && socket.assigns.current_scope.user && socket.assigns.current_scope.user.id
    block = Enum.find(socket.assigns.blocks, &(&1.id == block_id))
    not is_nil(user_id) && not is_nil(block) && block.created_by_id == user_id
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
end
