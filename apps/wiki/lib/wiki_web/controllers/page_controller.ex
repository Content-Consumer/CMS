defmodule WikiWeb.PageController do
  use WikiWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_scope] do
      redirect(conn, to: ~p"/blocks")
    else
      render(conn, :home)
    end
  end
end
