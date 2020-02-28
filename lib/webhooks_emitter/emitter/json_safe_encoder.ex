defmodule WebhooksEmitter.Emitter.JsonSafeEncoder do
  @moduledoc """
  Helper module to recursively encode a term for safe json encoding.

  Basically converts to string terms that cannot be directly encoded as json,
  like lists, tuples, refs and so on.
  """

  def encode(term) do
    term
    |> enc_impl()
  catch
    _class, _reason ->
      term
  end

  defp enc_impl(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> enc_impl()
  end

  defp enc_impl(term) when is_map(term) do
    term
    |> Enum.map(fn {k, v} ->
      {k |> enc_impl() |> encode_key(), enc_impl(v)}
    end)
    |> Map.new()
  end

  defp enc_impl(term) when is_pid(term) do
    "#{inspect(term)}"
  end

  defp enc_impl(term) when is_tuple(term) do
    term
    |> Tuple.to_list()
    |> enc_impl()
  end

  defp enc_impl(term) when is_reference(term) do
    "#{inspect(term)}"
  end

  defp enc_impl(term) when is_list(term) do
    term
    |> Enum.map(fn item -> enc_impl(item) end)
  end

  defp enc_impl(term) when is_bitstring(term) do
    case String.valid?(term) do
      true -> term
      false -> "#{inspect(term)}"
    end
  end

  defp enc_impl(term) do
    term
  end

  defp encode_key(key) when is_binary(key), do: key
  defp encode_key(key) when is_atom(key), do: key
  defp encode_key(key), do: "#{inspect(key)}"
end
