defmodule WebhooksEmitter.Emitter.JsonSafeEncoderTest do
  @moduledoc false
  use ExUnit.Case
  use ExUnitProperties

  alias WebhooksEmitter.Emitter.JsonSafeEncoder

  property "can encode any term" do
    check all(term <- terms()) do
      ret =
        term
        |> JsonSafeEncoder.encode()
        |> Jason.encode()

      assert {:ok, _} = ret
    end
  end

  defp terms do
    StreamData.one_of([
      term(),
      StreamData.list_of(term()),
      StreamData.map_of(keys(), term())
    ])
  end

  defp keys do
    StreamData.one_of([
      StreamData.string(:ascii),
      StreamData.atom(:alphanumeric),
      StreamData.float(),
      StreamData.integer()
    ])
  end
end
