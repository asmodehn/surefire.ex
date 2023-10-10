defmodule Surefire.BetsTest do
  use ExUnit.Case, async: true

  alias Surefire.Bets

  describe "new" do
    test "creates an empty map of bets" do
      assert Bets.new() == %{}
    end
  end

  describe "stake" do
    test "adds a stake for a new game event in bets map" do
      staked = %{} |> Bets.stake(:game_event_A, :my_avatar_id, 42)

      assert staked == %{
               game_event_A: [%Bets.Stake{holder: :my_avatar_id, amount: 42}]
             }
    end

    test "adds a stake for an existing game event in bets map" do
      staked =
        %{
          game_event_A: [%Bets.Stake{holder: :my_avatar_id, amount: 42}]
        }
        |> Bets.stake(:game_event_A, :another_avatar_id, 51)

      assert staked == %{
               game_event_A: [
                 %Bets.Stake{holder: :another_avatar_id, amount: 51},
                 %Bets.Stake{holder: :my_avatar_id, amount: 42}
               ]
             }
    end
  end

  describe "winnings/4" do
    test "compute bets change with win function" do
      bets = Bets.stake(%{}, :game_event_A, :my_avatar_id, 42)

      winnings =
        Bets.winnings(bets, :game_event_A, fn s -> %{s | amount: s.amount * 3} end, fn s ->
          %{s | amount: s.amount - 42}
        end)

      assert winnings == %{
               game_event_A: [
                 %Bets.Stake{holder: :my_avatar_id, amount: 42 * 3}
               ]
             }
    end

    test "compute bets change with lose function" do
      bets = Bets.stake(%{}, :game_event_A, :my_avatar_id, 42)

      winnings =
        Bets.winnings(bets, :game_event_B, fn s -> %{s | amount: s.amount * 3} end, fn s ->
          %{s | amount: s.amount - 41}
        end)

      assert winnings == %{
               game_event_A: [
                 %Surefire.Bets.Stake{holder: :my_avatar_id, amount: 1}
               ]
             }
    end

    test "stakes with amount 0 just disappear" do
      bets =
        Bets.stake(%{}, :game_event_A, :my_avatar_id, 42)
        |> Bets.stake(:game_event_A, :another_avatar_id, 51)

      winnings =
        Bets.winnings(bets, :game_event_B, fn s -> %{s | amount: s.amount * 3} end, fn s ->
          %{s | amount: s.amount - 42}
        end)

      assert winnings == %{
               game_event_A: [
                 %Surefire.Bets.Stake{holder: :another_avatar_id, amount: 9}
               ]
             }
    end

    test "no bets for a game event, means the game event key just disappear" do
      bets = Bets.stake(%{}, :game_event_A, :my_avatar_id, 42)

      winnings =
        Bets.winnings(bets, :game_event_B, fn s -> %{s | amount: s.amount * 3} end, fn s ->
          %{s | amount: s.amount - 42}
        end)

      assert winnings == %{}
    end
  end

  describe "winnings/3" do
    test "compute winnings with losing function setting amount to 0, collapsing losses" do
      bets = Bets.stake(%{}, :game_event_A, :my_avatar_id, 42)

      winnings = Bets.winnings(bets, :game_event_B, fn s -> %{s | amount: s.amount * 3} end)

      assert winnings == %{}
    end
  end
end
