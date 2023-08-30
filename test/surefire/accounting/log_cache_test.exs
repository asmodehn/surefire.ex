defmodule Surefire.LogCacheTest do
  use ExUnit.Case, async: true

  alias Surefire.Accounting.{LogCache, LogServer}

  describe "new/1" do
    setup do
      history_pid = start_supervised!(LogServer)

      t1 = LogServer.transfer(:alice, :bob, 42, history_pid)
      t2 = LogServer.transfer(:bob, :charlie, 33, history_pid)

      %{history_pid: history_pid, tids: [t1, t2]}
    end

    test "creates a partial cache of the history", %{history_pid: history_pid, tids: [_, t2]} do
      t3 = LogServer.transfer(:charlie, :alice, 51, history_pid)

      cache = LogCache.new(history_pid, from: t2) |> IO.inspect()

      assert cache.chunk.from == t2
      assert cache.chunk.until == t3
      assert cache.chunk.transactions |> Map.keys() == [t2, t3]
    end
  end
end
