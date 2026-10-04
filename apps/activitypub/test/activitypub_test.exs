defmodule ActivitypubTest do
  use ExUnit.Case
  doctest Activitypub

  test "greets the world" do
    assert Activitypub.hello() == :world
  end
end
