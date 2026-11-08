defmodule Deliberation do
  @behaviour Wiki.Block.Extension
  @behaviour Wiki.Extension

  alias Wiki.Block.Extension.Option
  alias Deliberation.{BlockParams, BlockKind}
  alias Wiki.{Repo, TextBlock, Dimension, Activity, SubBlock}

  @dimension_title "Deliberation"
  @argument_type "argument"

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
    import Ecto.Query

    BlockKind
    |> where([bk], bk.group_activity_id == ^activity_id)
    |> preload([bk], [:created_by, block: :block_content])
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
    import Ecto.Query

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
            href: "/ext/deliberation/activities/#{bk.group_activity_id}",
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
