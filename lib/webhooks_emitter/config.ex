defmodule WebhooksEmitter.Config do
  @moduledoc """
  Webhook emitter specification.
  """

  @type header_name :: String.t()
  @type header_content :: String.t()
  @type header :: {header_name, header_content}
  @type headers :: list(header())

  @type t :: %__MODULE__{
          url: nil | String.t(),
          secret: nil | String.t(),
          header_identifier: String.t(),
          max_retries: non_neg_integer(),
          request_timeout: non_neg_integer(),
          additional_headers: headers,
          http_client: module(),
          backoff_start: non_neg_integer(),
          backoff_limit: non_neg_integer()
        }

  @enforce_keys :url
  defstruct url: nil,
            secret: nil,
            header_identifier: "Webhooks",
            max_retries: 3,
            request_timeout: 5000,
            additional_headers: [],
            http_client: WebhooksEmitter.Emitter.HttpClient.HTTPoison,
            backoff_start: 1 * 1000,
            backoff_limit: 60 * 1000

  # @doc """
  # Callback to be implemented in order to retrieve a webhook configuration
  # """
  # @callback get(term) :: {:ok, __MODULE__.t()} | {:error, atom}

  @doc """
  Returns a new emitter config with the destination url set.

  ## Examples
        iex> WebhooksEmitter.Config.new("https://host.tld/hooks")
        %WebhooksEmitter.Config{url: "https://host.tld/hooks"}

  """
  @spec new(String.t()) :: WebhooksEmitter.Config.t()
  def new(url) when is_binary(url), do: %__MODULE__{url: url}

  @doc """
  Add a secret, which is used to compute the hmac hex digest of the body.

    ## Examples
        iex> "https://host.tld/hooks"
        ...> |> WebhooksEmitter.Config.new()
        ...> |> WebhooksEmitter.Config.secret("supersecret")
        %WebhooksEmitter.Config{url: "https://host.tld/hooks", secret: "supersecret"}

  """
  @spec secret(WebhooksEmitter.Config.t(), String.t()) :: WebhooksEmitter.Config.t()
  def secret(%__MODULE__{} = config, secret) when is_binary(secret) do
    %{config | secret: secret}
  end

  @doc """
  Allows to change the private header identifier. By default is `Webhooks`,
  so all private headers set by this library will have X-Webhooks prefix.

      ## Examples
        iex> "https://host.tld/hooks"
        ...> |> WebhooksEmitter.Config.new()
        ...> |> WebhooksEmitter.Config.header_identifier("Yourapp")
        %WebhooksEmitter.Config{url: "https://host.tld/hooks", header_identifier: "Yourapp"}

  """
  @spec header_identifier(WebhooksEmitter.Config.t(), String.t()) :: WebhooksEmitter.Config.t()
  def header_identifier(%__MODULE__{} = config, header_identifier)
      when is_binary(header_identifier) do
    %{config | header_identifier: header_identifier}
  end

  @doc """
  Set the HTTP request timeout, in milliseconds. By default is 5 seconds (5000 msec).

      ## Examples
        iex> "https://host.tld/hooks"
        ...> |> WebhooksEmitter.Config.new()
        ...> |> WebhooksEmitter.Config.request_timeout(2000)
        %WebhooksEmitter.Config{url: "https://host.tld/hooks", request_timeout: 2000}

  """
  @spec request_timeout(WebhooksEmitter.Config.t(), pos_integer) :: WebhooksEmitter.Config.t()
  def request_timeout(%__MODULE__{} = config, request_timeout)
      when is_integer(request_timeout) and request_timeout > 0 do
    %{config | request_timeout: request_timeout}
  end

  @doc """
  Set the number of max retries for each delivery. Defaults to 3.

      ## Examples
        iex> "https://host.tld/hooks"
        ...> |> WebhooksEmitter.Config.new()
        ...> |> WebhooksEmitter.Config.max_retries(43)
        %WebhooksEmitter.Config{url: "https://host.tld/hooks", max_retries: 43}

  """
  @spec max_retries(WebhooksEmitter.Config.t(), pos_integer) :: WebhooksEmitter.Config.t()
  def max_retries(%__MODULE__{} = config, max_retries)
      when is_integer(max_retries) and max_retries > 0 do
    %{config | max_retries: max_retries}
  end

  @doc """
  Set additional HTTP header to be sent along with the http request. Can be called multiple times.

      ## Examples
        iex> "https://host.tld/hooks"
        ...> |> WebhooksEmitter.Config.new()
        ...> |> WebhooksEmitter.Config.additional_header({"authorization", "bearer 4242"})
        %WebhooksEmitter.Config{url: "https://host.tld/hooks", additional_headers: [{"authorization", "bearer 4242"}]}

        iex> "https://host.tld/hooks"
        ...> |> WebhooksEmitter.Config.new()
        ...> |> WebhooksEmitter.Config.additional_header({"authorization", "bearer 4242"})
        ...> |> WebhooksEmitter.Config.additional_header({"Access-Control-Allow-Origin", "*"})
        %WebhooksEmitter.Config{url: "https://host.tld/hooks", additional_headers: [{"Access-Control-Allow-Origin", "*"}, {"authorization", "bearer 4242"}]}

  """
  @spec additional_header(WebhooksEmitter.Config.t(), header) ::
          WebhooksEmitter.Config.t()
  def additional_header(%__MODULE__{} = config, {header, value} = additional_header)
      when is_binary(header) and is_binary(value) do
    %{additional_headers: headers} = config
    new_headers = [additional_header | headers]
    %{config | additional_headers: new_headers}
  end
end
