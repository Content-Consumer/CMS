defmodule Deliberation.Web.Routes do
  defmacro routes do
    quote do
      scope "/ext/deliberation" do
        pipe_through :browser

        live "/argument", Deliberation.Web.ActivitiesLive, :index
        live "/argument/new", Deliberation.Web.ActivitiesLive, :new
      end
    end
  end
end
