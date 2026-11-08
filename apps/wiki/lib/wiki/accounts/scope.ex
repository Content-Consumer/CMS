defmodule Wiki.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `Wiki.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use in authorization checks,
  or to ensure specific code paths can only be accessed for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  ## Fields

    * `:user` — the authenticated user, or nil for anonymous requests
    * `:dimension` — the dimension the user is currently operating in, nil on
      wiki-global pages. Set by context-specific LiveViews in handle_params after
      verifying membership.
    * `:activity` — the group activity within the dimension, nil unless viewing
      a specific activity page.
  """

  alias Wiki.Accounts.User
  alias Wiki.Dimension.Dimension
  alias Wiki.Activity.GroupActivity

  defstruct user: nil, dimension: nil, activity: nil

  @doc "Creates a scope for the given user. Returns nil if no user is given."
  def for_user(%User{} = user), do: %__MODULE__{user: user}
  def for_user(nil), do: nil

  @doc "Narrows the scope to a specific dimension. Returns scope unchanged if nil."
  def with_dimension(%__MODULE__{} = scope, %Dimension{} = dimension) do
    %{scope | dimension: dimension}
  end

  def with_dimension(nil, _), do: nil

  @doc "Narrows the scope to a specific activity (dimension must already be set). Returns scope unchanged if nil."
  def with_activity(%__MODULE__{} = scope, %GroupActivity{} = activity) do
    %{scope | activity: activity}
  end

  def with_activity(nil, _), do: nil

  @doc """
  Returns true if the scope has an authenticated user who is a member of
  the current dimension. Use this to gate write actions on dimension pages.
  """
  def can_act?(%__MODULE__{user: user, dimension: dimension})
      when not is_nil(user) and not is_nil(dimension) do
    Wiki.Activity.user_in_dimension?(user.id, dimension.id)
  end

  def can_act?(_), do: false

  @doc "Returns true if can_act? and an activity is loaded in scope."
  def in_activity?(%__MODULE__{activity: activity} = scope) when not is_nil(activity) do
    can_act?(scope)
  end

  def in_activity?(_), do: false
end
