defmodule Wiki.Activity do
  import Ecto.Query
  alias Wiki.Repo
  alias Wiki.Activity.{DimensionActivityType, GroupActivity, UserActivity}

  # --- DimensionActivityType ---

  def get_activity_type_by(dimension_id, type) do
    DimensionActivityType
    |> where([t], t.dimension_id == ^dimension_id and t.type == ^type)
    |> Repo.one()
  end

  def create_activity_type(attrs) do
    %DimensionActivityType{}
    |> DimensionActivityType.changeset(attrs)
    |> Repo.insert()
  end

  def list_activity_types_for_dimension(dimension_id) do
    DimensionActivityType
    |> where([t], t.dimension_id == ^dimension_id)
    |> Repo.all()
  end

  # --- GroupActivity ---

  def get_group_activity(id) do
    case Repo.get(GroupActivity, id) do
      nil -> nil
      activity -> Repo.preload(activity, [:activity_type, :dimension])
    end
  end

  def create_group_activity(dimension_id, activity_type_id, name) do
    %GroupActivity{}
    |> GroupActivity.changeset(%{dimension_id: dimension_id, activity_type_id: activity_type_id, name: name})
    |> Repo.insert()
  end

  def list_group_activities_in_dimension(dimension_id) do
    GroupActivity
    |> where([g], g.dimension_id == ^dimension_id)
    |> preload(:activity_type)
    |> Repo.all()
  end

  def list_group_activities_by_type_in_dimension(type, dimension_id) do
    GroupActivity
    |> join(:inner, [g], t in DimensionActivityType, on: g.activity_type_id == t.id)
    |> where([g, t], g.dimension_id == ^dimension_id and t.type == ^type)
    |> preload(:activity_type)
    |> Repo.all()
  end

  # --- UserActivity ---

  def create_user_activity(dimension_id, user_id) do
    %UserActivity{}
    |> UserActivity.changeset(%{dimension_id: dimension_id, user_id: user_id})
    |> Repo.insert()
  end

  def list_user_activities_in_dimension(dimension_id) do
    UserActivity
    |> where([u], u.dimension_id == ^dimension_id)
    |> preload(:user)
    |> Repo.all()
  end

  def get_user_activity_in_dimension(user_id, dimension_id) do
    UserActivity
    |> where([u], u.user_id == ^user_id and u.dimension_id == ^dimension_id)
    |> preload(:user)
    |> Repo.one()
  end

  def user_in_dimension?(user_id, dimension_id) when is_binary(user_id) and is_binary(dimension_id) do
    Repo.exists?(
      from u in UserActivity,
        where: u.user_id == ^user_id and u.dimension_id == ^dimension_id
    )
  end

  def user_in_dimension?(_, _), do: false
end
