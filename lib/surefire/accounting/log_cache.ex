defmodule Surefire.Accounting.LogCache do
  alias Surefire.Accounting.LogServer
  alias Surefire.Accounting.History

  defstruct pid: nil,
            chunk: %History.Chunk{}

  def new(logserver_pid, opts \\ [from: nil, until: nil]) do
    from = opts |> Keyword.get(:from)
    until = opts |> Keyword.get(:until)

    chunk = LogServer.chunk(logserver_pid, from: from, until: until)

    %__MODULE__{
      pid: logserver_pid,
      chunk: chunk
    }
  end

  # TODO : stream() to get a cache as a stream... somehow...

  def next(%__MODULE__{pid: pid, chunk: last_chunk} = cache) do
    new(pid, from: last_chunk.until)
  end
end
