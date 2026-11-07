defmodule Deliberation.Web.Routes do
  defmacro routes do
    quote do
      scope "/ext/deliberation" do
        pipe_through :browser

        live "/activities", Deliberation.Web.ActivitiesLive, :index
        live "/activities/new", Deliberation.Web.ActivitiesLive, :new
      end
    end
  end
end
