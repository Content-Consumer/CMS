defmodule WikiWeb.UserLive.Registration do
  use WikiWeb, :live_view

  alias Wiki.Accounts
  alias Wiki.Accounts.{User, UsernameGenerator}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm px-4 py-8">
        <h1 class="text-xl font-semibold">Create an account</h1>
        <p class="text-sm text-base-content/60 mt-1">
          Already registered?
          <.link navigate={~p"/users/log-in"} class="text-brand hover:underline">Log in</.link>
        </p>

        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate" class="mt-6 space-y-4">
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />
          <div>
            <.input
              field={@form[:username]}
              type="text"
              label="Username"
              autocomplete="off"
              spellcheck="false"
            />
            <p class="text-xs text-base-content/50 mt-1">
              Lowercase letters, numbers and hyphens only. You can change this later.
            </p>
          </div>
          <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">
            Create an account
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: WikiWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    suggested = UsernameGenerator.generate()
    changeset = Accounts.change_user_registration(%User{}, %{"username" => suggested}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{user.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
