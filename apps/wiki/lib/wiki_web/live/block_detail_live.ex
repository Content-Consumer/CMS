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

            %{id: s.id, from_ix: s.from_ix, to_ix: s.to_ix, text: s.text || "", is_stale: is_stale}
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

  @impl true
  def handle_event("text_selected", _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} breadcrumbs={@breadcrumbs}>
      <div class="max-w-3xl mx-auto px-4 py-8">
        <div class="flex items-start justify-between mb-6">
          <div>
            <h1 :if={@title} class="text-2xl font-bold mb-1">{@title}</h1>
            <div class="flex items-center gap-2 flex-wrap">
              <code class="text-xs opacity-40">{@block.id}</code>
              <span :if={@block.created_by} class="text-xs opacity-40">
                · Created by {@block.created_by.email}
              </span>
            </div>
          </div>
          <.link
            :if={@current_scope && @current_scope.user && @current_scope.user.id == @block.created_by_id}
            href="/blocks"
            class="btn btn-ghost btn-sm gap-1"
          >
            <.icon name="hero-pencil-square" class="h-4 w-4" /> Edit
          </.link>
        </div>

        <div class="card bg-base-100 border border-base-300 mb-6">
          <div class="card-body py-4 px-5">
            <div
              id={"argdown-#{@block.id}"}
              phx-hook="ArgdownSelector"
              data-block-id={@block.id}
              data-subblocks={Jason.encode!(@subblocks_data)}
              class="block-preview text-sm"
            >
              {render_markdown(@block.block_content.content)}
            </div>
          </div>
        </div>

        <%!-- Highlights --%>
        <div :if={@subblocks_data != []} class="mb-6">
          <h2 class="text-xs font-semibold opacity-50 uppercase tracking-widest mb-3">
            Highlights ({length(@subblocks_data)})
          </h2>
          <div class="space-y-1">
            <.link
              :for={sub <- @subblocks_data}
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
