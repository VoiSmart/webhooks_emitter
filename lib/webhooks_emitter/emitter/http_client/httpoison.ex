defmodule WebhooksEmitter.Emitter.HttpClient.HTTPoison do
  @moduledoc false
  alias WebhooksEmitter.Config
  alias WebhooksEmitter.Emitter.{HttpClient, JsonSafeEncoder}

  @behaviour WebhooksEmitter.Emitter.HttpClient

  def do_post(
        event_name,
        payload,
        %Config{url: url} = config,
        request_id,
        http_lib \\ HTTPoison
      ) do
    case encode_body(payload) do
      {:ok, body} ->
        headers = default_headers(event_name, body, config, request_id)

        opts = options(config)

        url
        |> http_lib.post(body, headers, opts)

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
      {"x-#{hdi}-Delivery", request_id},
      {"user-agent", HttpClient.default_ua()}
    ]
    |> maybe_add_signature(payload, config)
  end

  defp options(%Config{} = config) do
    Keyword.new()
    |> add_timeout(config)
    |> add_insecure(config)
  end

  defp add_timeout(opts, %Config{request_timeout: timeout}) do
    opts
    |> Keyword.put(:timeout, timeout)
  end

  defp add_insecure(opts, %Config{insecure: false}), do: opts

  defp add_insecure(opts, %Config{insecure: true}) do
    opts
    |> Keyword.put(:hackney, [:insecure])
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

    [{"x-#{hdi}-Signature", "sha256:#{signature}"} | headers]
  rescue
    UndefinedFunctionError ->
      signature =
        :sha256
        |> :crypto.hmac(secret, payload)
        |> Base.hex_encode32(case: :lower, padding: false)

      [{"x-#{hdi}-Signature", "sha256:#{signature}"} | headers]
  end

  defp handle_response({:ok, %HTTPoison.Response{} = res}) do
    %{status_code: code} = res
    {:ok, %{status_code: code}}
  end

  defp handle_response({:error, _reason} = err), do: err
end
