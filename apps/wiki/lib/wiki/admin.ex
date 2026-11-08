defmodule Wiki.Admin do
  alias Wiki.Accounts.{User, UsernameGenerator}
  alias Wiki.Repo

  @doc """
  Registers a new user from the backend, generating a username and password.

  Returns `{:ok, %{user: user, username: username, password: password}}` on
  success, or `{:error, changeset}` if registration fails.

  The user is created pre-confirmed. The plaintext password is returned once
  and not stored — share it with the user and discard it.
  """
  def register_user(email) when is_binary(email) do
    username = generate_unique_username()
    password = generate_password()

    result =
      %User{}
      |> User.registration_changeset(%{email: email, username: username})
      |> User.password_changeset(%{password: password})
      |> User.confirm_changeset()
      |> Repo.insert()

    case result do
      {:ok, user} -> {:ok, %{user: user, username: username, password: password}}
      {:error, _} = err -> err
    end
  end

  defp generate_unique_username(attempts \\ 0) when attempts < 10 do
    candidate = UsernameGenerator.generate()

    if Repo.get_by(User, username: candidate) do
      generate_unique_username(attempts + 1)
    else
      candidate
    end
  end

  defp generate_password do
    :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
  end
end
