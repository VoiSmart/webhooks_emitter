defmodule WebhooksEmitter.Emitter.HttpClient.HTTPoisonTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import Hammox

  # import ExUnit.CaptureLog

  alias WebhooksEmitter.Config
  alias WebhooksEmitter.Emitter.HttpClient.HTTPoison, as: HTTPClient

  setup_all do
    Mox.defmock(HTTPoisonMock, for: HTTPoison.Base)

    :ok
  end

  setup :verify_on_exit!

  describe "do_post/4" do
    test "encodes a map payload" do
      HTTPoisonMock
      |> expect(:post, fn url, body, _headers, _opts ->
        assert is_binary(body)
        assert %{"foo" => "bar"} = Jason.decode!(body)

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           request: %HTTPoison.Request{url: url}
         }}
      end)

      config = %Config{url: "https://foo.bar", request_timeout: 1}

      assert {:ok, _} =
               HTTPClient.do_post(:an_event, %{foo: "bar"}, config, "request_id", HTTPoisonMock)
    end

    test "adds webhooks_emitter private http headers" do
      HTTPoisonMock
      |> expect(:post, fn url, _body, headers, _opts ->
        assert {"x-Webhooks-Event", :an_event} in headers
        assert {"x-Webhooks-Delivery", "request_id"} in headers
        assert {"content-type", "application/json"} in headers

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           request: %HTTPoison.Request{url: url}
         }}
      end)

      config = %Config{url: "https://foo.bar", request_timeout: 1}

      assert {:ok, _} =
               HTTPClient.do_post(:an_event, %{foo: "bar"}, config, "request_id", HTTPoisonMock)
    end

    test "adds webhooks_emitter signature if config has secret" do
      HTTPoisonMock
      |> expect(:post, fn url, body, headers, _opts ->
        {_, signature} = Enum.find(headers, nil, fn {"x-Webhooks-Signature", _} -> true end)

        assert_signature(signature, body, "supersecret")

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           request: %HTTPoison.Request{url: url}
         }}
      end)

      config = %Config{url: "https://foo.bar", request_timeout: 1, secret: "supersecret"}

      assert {:ok, _} =
               HTTPClient.do_post(:an_event, %{foo: "bar"}, config, "request_id", HTTPoisonMock)
    end

    test "request failure" do
      HTTPoisonMock
      |> expect(:post, fn _url, _body, _headers, _opts ->
        {:error, %HTTPoison.Error{}}
      end)

      config = %Config{url: "https://foo.bar", request_timeout: 1}

      assert {:error, _} =
               HTTPClient.do_post(:an_event, %{foo: "bar"}, config, "request_id", HTTPoisonMock)
    end
  end

  defp assert_signature(signature, body, secret) do
    assert <<"sha256:", hash::binary>> = signature

    my_hash =
      :hmac
      |> :crypto.mac(:sha256, secret, body)
      |> Base.hex_encode32(case: :lower, padding: false)

    assert hash == my_hash
  rescue
    UndefinedFunctionError ->
      assert <<"sha256:", hash::binary>> = signature

      my_hash =
        :sha256
        |> :crypto.hmac(secret, body)
        |> Base.hex_encode32(case: :lower, padding: false)

      assert hash == my_hash
  end
end
