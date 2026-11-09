defmodule Deliberation.Clustering do
  @hierarchical_threshold 0.5
  @similarity_threshold 0.6

  @doc """
  Builds display and numeric data from poll/voter state.
  Returns {users, vote_grid, numeric_vectors}
  - users: distinct User structs who voted on anything
  - vote_grid: %{user_id => %{block_id => :agree | :disagree | :none}}
  - numeric_vectors: %{user_id => [+1 | -1 | 0, ...]} in poll_items order
  """
  def build_vote_data(poll_items, voter_map, upvote_field, downvote_field) do
    upvote_id = upvote_field && upvote_field.id
    downvote_id = downvote_field && downvote_field.id

    all_voters =
      poll_items
      |> Enum.flat_map(fn bk ->
        bid = bk.block.id
        (get_in(voter_map, [bid, upvote_id]) || []) ++
          (get_in(voter_map, [bid, downvote_id]) || [])
      end)
      |> Enum.uniq_by(& &1.id)

    vote_grid =
      Map.new(all_voters, fn user ->
        per_block =
          Map.new(poll_items, fn bk ->
            bid = bk.block.id
            agree_set = MapSet.new(get_in(voter_map, [bid, upvote_id]) || [], & &1.id)
            disagree_set = MapSet.new(get_in(voter_map, [bid, downvote_id]) || [], & &1.id)

            vote =
              cond do
                MapSet.member?(agree_set, user.id) -> :agree
                MapSet.member?(disagree_set, user.id) -> :disagree
                true -> :none
              end

            {bid, vote}
          end)

        {user.id, per_block}
      end)

    block_ids = Enum.map(poll_items, & &1.block.id)

    numeric_vectors =
      Map.new(all_voters, fn user ->
        vec =
          Enum.map(block_ids, fn bid ->
            case vote_grid[user.id][bid] do
              :agree -> 1
              :disagree -> -1
              :none -> 0
            end
          end)

        {user.id, vec}
      end)

    {all_voters, vote_grid, numeric_vectors}
  end

  @doc """
  Agglomerative hierarchical clustering (average-linkage cosine similarity).
  Everyone ends up in a cluster. Returns list of clusters sorted by size desc.
  """
  def hierarchical(users, numeric_vectors) do
    case users do
      [] -> []
      [u] -> [[u]]
      _ ->
        clusters = Enum.map(users, &[&1])
        clusters |> do_merge(numeric_vectors) |> Enum.sort_by(&length/1, :desc)
    end
  end

  defp do_merge([_] = clusters, _), do: clusters

  defp do_merge(clusters, vectors) do
    indexed = Enum.with_index(clusters)

    {best_sim, i, j} =
      for({c1, i} <- indexed, {c2, j} <- indexed, i < j,
        do: {avg_linkage_sim(c1, c2, vectors), i, j})
      |> Enum.max_by(&elem(&1, 0))

    if best_sim >= @hierarchical_threshold do
      merged = Enum.at(clusters, i) ++ Enum.at(clusters, j)

      remaining =
        clusters
        |> Enum.with_index()
        |> Enum.reject(fn {_, idx} -> idx == i or idx == j end)
        |> Enum.map(&elem(&1, 0))

      do_merge([merged | remaining], vectors)
    else
      clusters
    end
  end

  defp avg_linkage_sim(c1, c2, vectors) do
    sims = for u1 <- c1, u2 <- c2, do: cosine_similarity(vectors[u1.id], vectors[u2.id])
    Enum.sum(sims) / length(sims)
  end

  defp cosine_similarity(v1, v2) do
    dot = Enum.zip(v1, v2) |> Enum.reduce(0, fn {a, b}, acc -> acc + a * b end)
    n1 = :math.sqrt(Enum.reduce(v1, 0, fn x, acc -> acc + x * x end))
    n2 = :math.sqrt(Enum.reduce(v2, 0, fn x, acc -> acc + x * x end))
    if n1 == 0 or n2 == 0, do: 0.0, else: dot / (n1 * n2)
  end

  @doc """
  Threshold-based similarity groups via connected components.
  Two voters are connected if they agree on >= 60% of their shared votes.
  Returns {groups, isolated_voters}.
  """
  def similarity_groups(users, numeric_vectors) do
    case users do
      [] ->
        {[], []}

      _ ->
        indexed = Enum.with_index(users)

        edges =
          for {u1, i} <- indexed,
              {u2, j} <- indexed,
              i < j,
              agreement_rate(numeric_vectors[u1.id], numeric_vectors[u2.id]) >= @similarity_threshold do
            {u1.id, u2.id}
          end

        components = connected_components(users, edges)
        {groups, singletons} = Enum.split_with(components, &(length(&1) > 1))
        {Enum.sort_by(groups, &length/1, :desc), List.flatten(singletons)}
    end
  end

  defp agreement_rate(v1, v2) do
    shared = Enum.zip(v1, v2) |> Enum.reject(fn {a, b} -> a == 0 or b == 0 end)

    if shared == [] do
      0.0
    else
      agreed = Enum.count(shared, fn {a, b} -> a == b end)
      agreed / length(shared)
    end
  end

  defp connected_components(users, edges) do
    parent = Map.new(users, fn u -> {u.id, u.id} end)

    parent =
      Enum.reduce(edges, parent, fn {id1, id2}, p ->
        r1 = find_root(p, id1)
        r2 = find_root(p, id2)
        if r1 != r2, do: Map.put(p, r1, r2), else: p
      end)

    users
    |> Enum.group_by(fn u -> find_root(parent, u.id) end)
    |> Map.values()
  end

  defp find_root(parent, id) do
    case Map.fetch!(parent, id) do
      ^id -> id
      parent_id -> find_root(parent, parent_id)
    end
  end
end
