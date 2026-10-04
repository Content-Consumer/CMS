defmodule Wiki.Repo do
  use Ecto.Repo,
    otp_app: :wiki,
    adapter: Ecto.Adapters.Postgres
end
