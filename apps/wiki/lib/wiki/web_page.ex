defmodule Wiki.WebPage do
  @doc """
  Fetches a URL and extracts article content as markdown.
  Returns {:ok, %{title: string, content: string, url: string}} or {:error, reason}.
  """
  def fetch_and_extract(url) do
    case Req.get(url,
           headers: [{"user-agent", "Mozilla/5.0 (compatible; CMS/1.0)"}],
           redirect: true,
           receive_timeout: 15_000
         ) do
      {:ok, %{status: status, body: html}} when status in 200..299 ->
        {:ok, extract(html, url)}

      {:ok, %{status: status}} ->
        {:error, "Server returned HTTP #{status}"}

      {:error, %{reason: reason}} ->
        {:error, "Request failed: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp extract(html, url) do
    parsed = Floki.parse_document!(html)
    title = extract_title(parsed)
    content_node = find_content(parsed)
    markdown = node_to_markdown(content_node) |> clean_markdown()
    %{title: title, content: markdown, url: url}
  end

  defp extract_title(parsed) do
    og =
      parsed
      |> Floki.find("meta[property='og:title']")
      |> Floki.attribute("content")
      |> List.first()

    page_title =
      parsed
      |> Floki.find("title")
      |> Floki.text()
      |> String.trim()

    h1 =
      case Floki.find(parsed, "article h1, main h1, h1") do
        [node | _] -> node |> Floki.text() |> String.trim()
        [] -> nil
      end

    og || (if page_title != "", do: page_title) || h1 || ""
  end

  defp find_content(parsed) do
    article = Floki.find(parsed, "article") |> List.first()
    main = Floki.find(parsed, "main") |> List.first()

    content_selectors = [
      "[class*='article-body']",
      "[class*='post-content']",
      "[class*='entry-content']",
      "[class*='article-content']",
      "[class*='story-body']",
      "[class*='content-body']",
      "[itemprop='articleBody']"
    ]

    content_div =
      Enum.find_value(content_selectors, fn sel ->
        case Floki.find(parsed, sel) do
          [node | _] -> node
          _ -> nil
        end
      end)

    article || content_div || main || (Floki.find(parsed, "body") |> List.first()) || parsed
  end

  defp node_to_markdown(nodes) when is_list(nodes) do
    Enum.map_join(nodes, "", &node_to_markdown/1)
  end

  defp node_to_markdown(text) when is_binary(text), do: text
  defp node_to_markdown(nil), do: ""

  defp node_to_markdown({tag, _attrs, children}) do
    case tag do
      skip when skip in ~w(script style nav header footer aside iframe noscript form button input select) ->
        ""

      "h1" -> "# #{inline_text(children)}\n\n"
      "h2" -> "## #{inline_text(children)}\n\n"
      "h3" -> "### #{inline_text(children)}\n\n"
      "h4" -> "#### #{inline_text(children)}\n\n"
      "h5" -> "##### #{inline_text(children)}\n\n"
      "h6" -> "###### #{inline_text(children)}\n\n"

      "p" ->
        text = inline_to_md(children)
        if String.trim(text) == "", do: "", else: "#{text}\n\n"

      "br" -> "\n"
      "hr" -> "\n---\n\n"

      "blockquote" ->
        inner = node_to_markdown(children) |> String.trim()
        lines = String.split(inner, "\n")
        Enum.map_join(lines, "\n", &"> #{&1}") <> "\n\n"

      "pre" ->
        code =
          case Floki.find({"pre", [], children}, "code") do
            [{_, _, code_children} | _] -> Floki.text(code_children)
            _ -> inline_text(children)
          end

        "```\n#{code}\n```\n\n"

      "ul" ->
        li_items(children, fn text -> "- #{text}\n" end) <> "\n"

      "ol" ->
        children
        |> Enum.filter(fn
          {"li", _, _} -> true
          _ -> false
        end)
        |> Enum.with_index(1)
        |> Enum.map_join("", fn {{"li", _, li_children}, i} ->
          "#{i}. #{inline_text(li_children)}\n"
        end)
        |> then(& &1 <> "\n")

      "li" -> ""

      "table" -> ""

      _ -> node_to_markdown(children)
    end
  end

  defp li_items(children, formatter) do
    children
    |> Enum.filter(fn
      {"li", _, _} -> true
      _ -> false
    end)
    |> Enum.map_join("", fn {"li", _, li_children} ->
      formatter.(inline_text(li_children))
    end)
  end

  defp inline_to_md(nodes) when is_list(nodes), do: Enum.map_join(nodes, "", &inline_to_md/1)
  defp inline_to_md(text) when is_binary(text), do: text
  defp inline_to_md({"strong", _, children}), do: "**#{inline_text(children)}**"
  defp inline_to_md({"b", _, children}), do: "**#{inline_text(children)}**"
  defp inline_to_md({"em", _, children}), do: "*#{inline_text(children)}*"
  defp inline_to_md({"i", _, children}), do: "*#{inline_text(children)}*"
  defp inline_to_md({"code", _, children}), do: "`#{inline_text(children)}`"
  defp inline_to_md({"br", _, _}), do: "\n"
  defp inline_to_md({"a", _, children}), do: inline_text(children)
  defp inline_to_md({_, _, children}), do: inline_text(children)

  defp inline_text(nodes) when is_list(nodes), do: Enum.map_join(nodes, "", &inline_text/1)
  defp inline_text(text) when is_binary(text), do: text
  defp inline_text({_, _, children}), do: inline_text(children)

  defp clean_markdown(md) do
    md
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end
end
