defmodule Surefire.Avatar.AutomatedTest do
  use ExUnit.Case, async: true

  alias Surefire.Avatar.Automated

  describe "automatize/2" do
    test "adds a function to serve as automation for a later call" do
      auto = %Automated{} |> Automated.automatize(:ask, fn _prompt -> "42" end)
      assert auto.ask.("smthg smthg question?") == "42"
    end
  end

  describe "decide/2" do
    test "calls the automated decide function" do
      auto = %Automated{} |> Automated.automatize(:decide, fn _prompt, _choice -> "A" end)

      assert Automated.decide(auto, "smthg smthg choice?", %{
               "choice 1" => "A",
               "choice 2" => "B"
             }) == "A"
    end
  end

  describe "ask/2" do
    test "calls the automated ask function" do
      auto = %Automated{} |> Automated.automatize(:ask, fn _prompt -> "42" end)
      assert Automated.ask(auto, "smthg smthg question?") == "42"
    end
  end

  describe "tell/2" do
    test "calls the automated ask function" do
      auto = %Automated{} |> Automated.automatize(:tell, fn _prompt -> nil end)
      assert Automated.tell(auto, "smthg smthg question?") == nil
    end
  end

  describe "bet_transfer/3" do
  end

  describe "gain_transfer/3" do
  end
end

defmodule Surefire.AvatarTest do
  use ExUnit.Case, async: true
  # TODO...

  describe "ask/2" do
  end

  describe "decide/2" do
  end

  describe "call_mutation/2" do
  end

  describe "call_action/2" do
  end
end
