defmodule WebhooksEmitter.Emitter.HttpClient do
  @moduledoc false
  alias WebhooksEmitter.Config
  alias WebhooksEmitter.Emitter.JsonSafeEncoder

  @behaviour WebhooksEmitter.Emitter.HttpClientInterface

  def do_post(
        event_name,
        payload,
        %Config{url: url, request_timeout: timeout} = config,
        request_id
      ) do
    case encode_body(payload) do
      {:ok, body} ->
        headers = default_headers(event_name, body, config, request_id)

        opts = [timeout: timeout]

        url
        |> HTTPoison.post(body, headers, opts)

      err ->
        err
    end
    |> handle_response()
  end

  defp encode_body(payload) do
    payload
    |> JsonSafeEncoder.encode()
    |> Jason.encode(maps: :strict)
  end

  defp default_headers(
         event_name,
         payload,
         %Config{header_identifier: hdi} = config,
         request_id
       ) do
    [
      {"content-type", "application/json"},
      {"x-#{hdi}-Event", event_name},
      {"x-#{hdi}-Delivery", request_id}
    ]
    |> maybe_add_signature(payload, config)
  end

  defp maybe_add_signature(headers, _, %Config{secret: nil}), do: headers

  defp maybe_add_signature(headers, payload, %Config{
         secret: secret,
         header_identifier: hdi
       }) do
    signature =
      :hmac
      |> :crypto.mac(:sha256, secret, payload)
      |> Base.hex_encode32(case: :lower, padding: false)

    [{"x-#{hdi}-Signature", signature} | headers]
  end

  defp handle_response({:ok, %HTTPoison.Response{} = res}) do
    %{status_code: code} = res
    {:ok, %{status_code: code}}
  end

  defp handle_response({:error, _reason} = err), do: err
end
