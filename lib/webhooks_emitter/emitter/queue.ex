defmodule WebhooksEmitter.Emitter.Queue do
  @moduledoc false

  def new do
    :queue.new()
  end

  def pop_last(q) do
    case :queue.out_r(q) do
      {{:value, value}, new_q} -> {:ok, new_q, value}
      {:empty, _q} -> {:error, :empty}
    end
  end

  def put_last(q, item) do
    :queue.in(item, q)
  end

  def put(q, item) do
    :queue.in_r(item, q)
  end

  def empty?(q) do
    :queue.is_empty(q)
  end
end
