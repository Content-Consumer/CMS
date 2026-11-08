defmodule WikiWeb.SubBlockDetailLive do
  use WikiWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       subblock: nil,
       block: nil,
       is_stale: false,
       is_long: false,
       show_full: false,
       subblock_hook_data: [],
       referencing_blocks: [],
       breadcrumbs: []
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    subblock = Wiki.SubBlock.get_subblock_detail(id)

    socket =
      if subblock do
        block = subblock.block
        current_content = block.block_content.content

        is_stale =
          is_nil(subblock.block_content_version) or
            subblock.block_content_version.content != current_content

        subblock_hook_data = [
          %{
            id: subblock.id,
            from_ix: subblock.from_ix,
            to_ix: subblock.to_ix,
            text: subblock.text || "",
            is_stale: is_stale
          }
        ]

        referencing_blocks = Wiki.SubBlock.find_blocks_referencing_subblock(id)

        word_count =
          current_content |> String.split(~r/\s+/, trim: true) |> length()

        short_id = String.slice(id, 0, 14) <> "…"

        assign(socket,
          subblock: subblock,
          block: block,
          is_stale: is_stale,
          is_long: word_count > 100,
          show_full: false,
          subblock_hook_data: subblock_hook_data,
          referencing_blocks: referencing_blocks,
          page_title: short_id,
          breadcrumbs: [
            %{label: "Blocks", path: "/blocks"},
            %{label: String.slice(block.id, 0, 12) <> "…", path: "/blocks/#{block.id}"},
            %{label: short_id, path: nil}
          ]
        )
      else
        socket
        |> put_flash(:error, "Highlight not found")
        |> push_navigate(to: "/blocks")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_full", _, socket) do
    {:noreply, assign(socket, show_full: !socket.assigns.show_full)}
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
            <div class="flex items-center gap-2 mb-1 flex-wrap">
              <code class="text-xs opacity-50">{@subblock.id}</code>
              <span :if={@is_stale} class="badge badge-xs badge-warning">stale</span>
              <span :if={@subblock.created_by} class="text-xs opacity-40">
                · Highlighted by {@subblock.created_by.email}
              </span>
            </div>
            <p class="text-xs opacity-40">
              From block
              <.link href={"/blocks/#{@block.id}"} class="underline opacity-80">{@block.id}</.link>
              <span :if={@block.created_by}> · Created by {@block.created_by.email}</span>
            </p>
          </div>
        </div>

        <%!-- Quoted text --%>
        <div class="card bg-base-200 border border-base-300 mb-6">
          <div class="card-body py-3 px-5">
            <p :if={!@is_stale} class="text-sm italic opacity-70">"{@subblock.text}"</p>
            <div :if={@is_stale}>
              <p class="text-sm italic opacity-70 line-through mb-1">"{@subblock.text}"</p>
              <p class="text-xs opacity-50">
                The source block has been edited since this highlight was created.
              </p>
            </div>
          </div>
        </div>

        <%!-- Parent block with highlight rendered --%>
        <div class="card bg-base-100 border border-base-300 mb-6">
          <div class="card-body py-4 px-5">
            <div class="flex items-center justify-between mb-3">
              <p class="text-xs font-medium opacity-40 uppercase tracking-widest">Source block</p>
              <.link
                href={"/blocks/#{@block.id}"}
                class="text-xs opacity-40 font-mono hover:opacity-70 hover:underline"
              >
                {@block.id}
              </.link>
            </div>
            <div class={["relative", if(@is_long && !@show_full, do: "block-preview-collapsed")]}>
              <div
                id={"argdown-#{@block.id}"}
                phx-hook="ArgdownSelector"
                data-block-id={@block.id}
                data-subblocks={Jason.encode!(@subblock_hook_data)}
                class="block-preview text-sm"
              >
                {render_markdown(@block.block_content.content)}
              </div>
            </div>
            <button
              :if={@is_long}
              phx-click="toggle_full"
              class="btn btn-ghost btn-xs mt-3 w-full"
            >
              {if @show_full, do: "Collapse", else: "Show full block"}
            </button>
          </div>
        </div>

        <%!-- Blocks that reference this subblock --%>
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
