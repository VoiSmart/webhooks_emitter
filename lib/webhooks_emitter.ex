defmodule WebhooksEmitter do
  @moduledoc """
  Documentation for `WebhooksEmitter`.
  """
  alias WebhooksEmitter.Config
  alias WebhooksEmitter.Emitter

  @type emitter_id :: term
  @type url :: String.t()
  @type event_name :: String.t() | atom()
  @type event_names :: [event_name(), ...]

  @doc """
  Attaches a new emitter to the event.

  emitter_id must be unique, if another emitter with the same ID already exists {:error, :already_exists} is returned.

  Each emitter is a separate process that performs HTTP operations, while keeping a queue of events in order to performs retries.
  So events handled by the same emitter are processed sequentially. This means also that if a request fails and more events are to be
  handled by the emitter, the events are queued until the current delivery succeed or fails because of hitting the maximum retries.
  At this point the event is lost forever.

  If same url needs to process many events, `attach_many/3` can be used.
  """
  @spec attach(emitter_id, event_name, Config.t()) ::
          :ok | {:error, :already_exists}
  def attach(emitter_id, event_name, %Config{} = config)
      when is_binary(event_name) or is_atom(event_name) do
    attach_many(emitter_id, [event_name], config)
  end

  @doc """
  Attaches a new emitter to a list of events.

  Accepts a list of event names. Apart from that, works like `attach/3`.
  """
  @spec attach_many(emitter_id, event_names, Config.t()) ::
          :ok | {:error, :already_exists}
  def attach_many(emitter_id, event_names, %Config{} = config)
      when is_list(event_names) do
    case Emitter.start_emitter(emitter_id, event_names, config) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> {:error, :already_exists}
    end
  end

  @doc """
  Detaches an emitter.

  Stops the process and removes it from the supervision tree, disregarding any queued message. Always returns :ok.
  """
  def detach(emitter_id) do
    Emitter.stop_emitter(emitter_id)
    :ok
  end

  @doc """
  Emits an event, invoking all emitters attached to it.

  Allows to set a request_id, that is inserted into the HTTP request as X-Webhooks-Delivery private header.
  If the request id is not set, a new one is generated and returned as `{:ok, UUID.uuid4()}`.
  Otherwise just return the {:ok, request_id} tuple.

  The map payload is parsed in order to be safe for json encoding, basically ensures that any key or value that
  cannot be directly converted to string is handled correctly by inspecting them.

  So keys and values in the payload are converted like:
  - values as tuples are transformed to list
  - keys as tuples are transformed to list, then inspected to obtain a string
  - keys as list are inspected to obtain a string
  - refs are always inspected

  """
  def emit(event_name, payload, request_id \\ nil)

  def emit(event_name, payload, nil) when is_map(payload) do
    emit(event_name, payload, UUID.uuid4())
  end

  def emit(event_name, payload, request_id)
      when (is_binary(event_name) or is_atom(event_name)) and is_map(payload) do
    Emitter.emit(event_name, payload, request_id)

    {:ok, request_id}
  end
end
