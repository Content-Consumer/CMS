defmodule ComputationTest do
  use ExUnit.Case
  doctest Computation

  test "greets the world" do
    assert Computation.hello() == :world
  end
end
