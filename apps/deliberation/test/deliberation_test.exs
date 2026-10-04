defmodule DeliberationTest do
  use ExUnit.Case
  doctest Deliberation

  test "greets the world" do
    assert Deliberation.hello() == :world
  end
end
