defmodule Wiki.Accounts.UsernameGenerator do
  @adjectives ~w[
    amber ancient arctic bold brave bright calm clear cold crisp
    dark deep distant dusty early east elder emerald fallen far
    fast fierce firm fleet forest free fresh golden grand green
    grey hidden high hollow iron keen late light lone lost low
    lunar midnight misty morning noble north old pale quiet rapid
    rare red risen rocky rough royal safe sharp silent silver
    slow small soft solar solid south stern still stone strong
    swift tall tame true west wild wise young
  ]

  @nouns ~w[
    arrow ash basin bear birch brook canyon cave cedar cloud
    coast cove creek cypress dawn dew drift dune dust eagle
    falls fern field fire fjord flame flint fog forest frost
    gate glade glen grove hawk heath hill hollow horizon isle
    lake larch laurel leaf ledge loch lynx maple marsh meadow
    mesa mist moon moss mound oak pass path peak pine plain
    pool rain ravine reed ridge rim river rock root rose shore
    sky slope snow spire spring star stone stream summit thorn
    tide trail vale vale vault wave willow wind wood
  ]

  def generate do
    adj = Enum.random(@adjectives)
    noun = Enum.random(@nouns)
    suffix = :rand.uniform(9999) |> Integer.to_string() |> String.pad_leading(4, "0")
    "#{adj}-#{noun}-#{suffix}"
  end
end
