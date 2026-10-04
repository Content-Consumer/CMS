defmodule WikiWeb.PageController do
  use WikiWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
