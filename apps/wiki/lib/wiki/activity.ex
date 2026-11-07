defmodule Wiki.Activity do
  import Ecto.Query
  alias Wiki.Repo
  alias Wiki.Activity.{DimensionActivityType, GroupActivity, UserActivity}

  # --- DimensionActivityType ---

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

  def create_group_activity(dimension_id, activity_type_id) do
    %GroupActivity{}
    |> GroupActivity.changeset(%{dimension_id: dimension_id, activity_type_id: activity_type_id})
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
end
