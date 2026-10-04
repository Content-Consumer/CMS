defmodule SafetyTest do
  use ExUnit.Case
  doctest Safety

  test "greets the world" do
    assert Safety.hello() == :world
  end
end
