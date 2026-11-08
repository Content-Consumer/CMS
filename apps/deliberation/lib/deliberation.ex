defmodule Deliberation do
  @behaviour Wiki.Block.Extension
  @behaviour Wiki.Extension

  import Ecto.Query

  alias Wiki.Block.Extension.Option
  alias Deliberation.{BlockParams, BlockKind, VotingActivity, VotingActivityLink, BlockVoteReason}
  alias Wiki.{Repo, TextBlock, Dimension, Activity, SubBlock}

  @dimension_title "Deliberation"
  @argument_type "argument"
  @voting_type "deliberation_voting"

  @impl Wiki.Extension
  def dimensions do
    [
      %{title: @dimension_title, description: "A space for structured group deliberation"}
    ]
  end

  @impl Wiki.Extension
  def activity_types do
    [
      %{dimension_title: @dimension_title, name: "Open Discussion", type: "deliberation"},
      %{dimension_title: @dimension_title, name: "Voting", type: "deliberation_voting"},
      %{dimension_title: @dimension_title, name: "Argument", type: @argument_type}
    ]
  end

  @impl Wiki.Extension
  def metadata_fields do
    [
      %{name: "upvote", label: "Upvote", type: "vote", dimension_title: @dimension_title},
      %{name: "downvote", label: "Downvote", type: "vote", dimension_title: @dimension_title}
    ]
  end

  @impl Wiki.Extension
  def relationship_types do
    [
      %{name: "supports", label: "Supports", directional: true,  dimension_title: @dimension_title},
      %{name: "attacks",  label: "Attacks",  directional: true,  dimension_title: @dimension_title}
    ]
  end

  # --- Voting Activities ---

  def create_voting_activity(name, objective, dimension_id \\ nil) do
    dim =
      if dimension_id do
        Repo.get(Wiki.Dimension.Dimension, dimension_id)
      else
        Dimension.get_dimension_by_title(@dimension_title)
      end

    type = if dim, do: Activity.get_activity_type_by(dim.id, @voting_type)

    with dim when not is_nil(dim) <- dim,
         type when not is_nil(type) <- type,
         {:ok, group_activity} <- Activity.create_group_activity(dim.id, type.id, name),
         {:ok, voting_activity} <-
           Repo.insert(VotingActivity.changeset(%VotingActivity{}, %{
             group_activity_id: group_activity.id,
             objective: if(objective == "", do: nil, else: objective)
           })) do
      {:ok, %{group_activity | activity_type: type}, voting_activity}
    else
      nil -> {:error, :not_configured}
      {:error, _} = error -> error
    end
  end

  def get_voting_activity(group_activity_id) do
    VotingActivity
    |> where([va], va.group_activity_id == ^group_activity_id)
    |> preload(links: :argument_activity)
    |> Repo.one()
  end

  def list_voting_activities do
    case Dimension.get_dimension_by_title(@dimension_title) do
      nil -> []
      dim ->
        Activity.list_group_activities_by_type_in_dimension(@voting_type, dim.id)
    end
  end

  def link_argument_activity(voting_activity_id, argument_activity_id) do
    %VotingActivityLink{}
    |> VotingActivityLink.changeset(%{
      voting_activity_id: voting_activity_id,
      argument_activity_id: argument_activity_id
    })
    |> Repo.insert()
  end

  def unlink_argument_activity(link_id) do
    case Repo.get(VotingActivityLink, link_id) do
      nil -> {:error, :not_found}
      link -> Repo.delete(link)
    end
  end

  def create_poll_item(content, group_activity_id, user_id \\ nil) do
    Repo.transaction(fn ->
      with {:ok, block} <- TextBlock.create_block(content, user_id),
           dim when not is_nil(dim) <- Dimension.get_dimension_by_title(@dimension_title),
           {:ok, _} <- Dimension.add_block_to_dimension(block.id, dim.id),
           {:ok, block_kind} <-
             Repo.insert(BlockKind.changeset(%BlockKind{}, %{
               block_id: block.id,
               group_activity_id: group_activity_id,
               kind: "poll_item",
               created_by_id: user_id
             })) do
        {block, block_kind}
      else
        nil -> Repo.rollback(:dimension_not_found)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def list_poll_items(activity_id) do
    BlockKind
    |> where([bk], bk.group_activity_id == ^activity_id and bk.kind == "poll_item")
    |> preload([bk], [:created_by, block: :block_content])
    |> Repo.all()
  end

  def list_argument_blocks_for_voting_activity(voting_activity_id) do
    VotingActivityLink
    |> where([l], l.voting_activity_id == ^voting_activity_id)
    |> select([l], l.argument_activity_id)
    |> Repo.all()
    |> case do
      [] -> []
      activity_ids ->
        BlockKind
        |> where([bk], bk.group_activity_id in ^activity_ids and bk.kind == "statement")
        |> preload([bk], [:created_by, block: :block_content, group_activity: []])
        |> Repo.all()
    end
  end

  def set_vote_reason(block_id, voting_activity_id, user_id, reason_block_id) do
    case Repo.get_by(BlockVoteReason, block_id: block_id, voting_activity_id: voting_activity_id, user_id: user_id) do
      nil ->
        %BlockVoteReason{}
        |> BlockVoteReason.changeset(%{
          block_id: block_id,
          voting_activity_id: voting_activity_id,
          user_id: user_id,
          reason_block_id: reason_block_id
        })
        |> Repo.insert()

      existing ->
        existing
        |> BlockVoteReason.changeset(%{reason_block_id: reason_block_id})
        |> Repo.update()
    end
  end

  def clear_vote_reason(block_id, voting_activity_id, user_id) do
    case Repo.get_by(BlockVoteReason, block_id: block_id, voting_activity_id: voting_activity_id, user_id: user_id) do
      nil -> :ok
      record -> Repo.delete(record) |> then(fn _ -> :ok end)
    end
  end

  def load_vote_reasons(block_ids, voting_activity_id, user_id) do
    BlockVoteReason
    |> where([r], r.block_id in ^block_ids and r.voting_activity_id == ^voting_activity_id and r.user_id == ^user_id)
    |> preload(reason_block: :block_content)
    |> Repo.all()
    |> Map.new(&{&1.block_id, &1})
  end

  # --- Argument blocks (existing) ---

  def create_argdown_block(original_block_id, selected_text, from_ix, to_ix, kind, group_activity_id, user_id \\ nil) do
    Repo.transaction(fn ->
      with {:ok, _sub_block} <- SubBlock.create_subblock(original_block_id, from_ix, to_ix, nil, user_id),
           {:ok, new_block} <- TextBlock.create_block(selected_text, user_id),
           dim when not is_nil(dim) <- Dimension.get_dimension_by_title(@dimension_title),
           {:ok, _} <- Dimension.add_block_to_dimension(new_block.id, dim.id),
           {:ok, block_kind} <-
             Repo.insert(BlockKind.changeset(%BlockKind{}, %{
               block_id: new_block.id,
               group_activity_id: group_activity_id,
               kind: kind,
               created_by_id: user_id
             })) do
        {new_block, block_kind}
      else
        nil -> Repo.rollback(:dimension_not_found)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def list_blocks_for_activity(activity_id) do
    BlockKind
    |> where([bk], bk.group_activity_id == ^activity_id)
    |> preload([bk], [:created_by, block: :block_content])
    |> Repo.all()
  end

  # --- Sources ---

  def list_sources_for_activity(activity_id) do
    BlockKind
    |> where([bk], bk.group_activity_id == ^activity_id and bk.kind == "source")
    |> preload([bk], [:created_by, block: :block_content])
    |> Repo.all()
  end

  def add_source_block(block_id, group_activity_id, user_id \\ nil) do
    %BlockKind{}
    |> BlockKind.changeset(%{
      block_id: block_id,
      group_activity_id: group_activity_id,
      kind: "source",
      created_by_id: user_id
    })
    |> Repo.insert()
  end

  def create_source_text_block(content, group_activity_id, user_id \\ nil) do
    Repo.transaction(fn ->
      with {:ok, block} <- Wiki.TextBlock.create_block(content, user_id),
           dim when not is_nil(dim) <- Dimension.get_dimension_by_title(@dimension_title),
           {:ok, _} <- Dimension.add_block_to_dimension(block.id, dim.id),
           {:ok, block_kind} <-
             Repo.insert(BlockKind.changeset(%BlockKind{}, %{
               block_id: block.id,
               group_activity_id: group_activity_id,
               kind: "source",
               created_by_id: user_id
             })) do
        {block, block_kind}
      else
        nil -> Repo.rollback(:dimension_not_found)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def remove_source_block(block_id, group_activity_id) do
    in_use =
      BlockKind
      |> where([bk], bk.block_id == ^block_id and bk.group_activity_id == ^group_activity_id and bk.kind in ["argument", "statement"])
      |> Repo.exists?()

    if in_use do
      {:error, :in_use}
    else
      case Repo.get_by(BlockKind, block_id: block_id, group_activity_id: group_activity_id, kind: "source") do
        nil -> {:error, :not_found}
        bk -> Repo.delete(bk)
      end
    end
  end

  def source_block_ids_for_activity(activity_id) do
    BlockKind
    |> where([bk], bk.group_activity_id == ^activity_id and bk.kind == "source")
    |> select([bk], bk.block_id)
    |> Repo.all()
  end

  def list_argument_activities do
    case Dimension.get_dimension_by_title(@dimension_title) do
      nil -> []
      dim ->
        case Activity.get_activity_type_by(dim.id, @argument_type) do
          nil -> []
          type -> Activity.list_group_activities_by_type_in_dimension(@argument_type, dim.id)
                  |> Enum.map(&%{&1 | activity_type: type})
        end
    end
  end

  def create_argument_activity(name) do
    require Logger
    dim = Dimension.get_dimension_by_title(@dimension_title)
    type = if dim, do: Activity.get_activity_type_by(dim.id, @argument_type)
    Logger.warning("[Deliberation] create_argument_activity: dim=#{inspect(dim && dim.id)} type=#{inspect(type && type.id)}")

    with dim when not is_nil(dim) <- dim,
         type when not is_nil(type) <- type,
         {:ok, activity} <- Activity.create_group_activity(dim.id, type.id, name) do
      {:ok, %{activity | activity_type: type}}
    else
      nil -> {:error, :not_configured}
      {:error, _} = error -> error
    end
  end

  @impl Wiki.Block.Extension
  def name, do: "Deliberation"

  @impl Wiki.Block.Extension
  def block_detail_sections(block) do
    block_kinds =
      BlockKind
      |> where([bk], bk.block_id == ^block.id)
      |> preload(:group_activity)
      |> Repo.all()

    if block_kinds == [] do
      []
    else
      items =
        Enum.map(block_kinds, fn bk ->
          %{
            label: bk.group_activity.name,
            href: "/ext/deliberation/argument/#{bk.group_activity_id}",
            badge: bk.kind
          }
        end)

      [%{title: "Activity Memberships", items: items}]
    end
  end

  @impl Wiki.Block.Extension
  def home_path, do: "/ext/deliberation"

  @impl Wiki.Block.Extension
  def block_options(block) do
    [
      %Option{
        label: "Start deliberation",
        icon: "hero-chat-bubble-left-right",
        event: "deliberation_start",
        block_id: block.id,
        params: %BlockParams{block_id: block.id}
      },
      %Option{
        label: "View deliberations",
        icon: "hero-list-bullet",
        event: "deliberation_view",
        block_id: block.id,
        params: %BlockParams{block_id: block.id}
      }
    ]
  end
end
