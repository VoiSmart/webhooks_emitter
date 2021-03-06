defmodule WebhooksEmitter.Interface do
  @moduledoc """
  Specification for WebhooksEmitter
  """

  @type emitter_id :: term
  @type emitter_config :: WebhooksEmitter.Config.t()
  @type event_name :: String.t() | atom()
  @type event_names :: [event_name(), ...]
  @type event_payload :: map()
  @type request_id :: String.t() | nil
  @type url :: String.t()

  @callback attach(emitter_id, event_name, emitter_config) ::
              :ok | {:error, :already_exists | :already_present}
  @callback attach_many(emitter_id, event_names, emitter_config) ::
              :ok | {:error, :already_exists | :already_present}
  @callback detach(emitter_id) :: :ok
  @callback pause(emitter_id) :: :ok
  @callback emit(event_name, event_payload, request_id) :: {:ok, request_id}
  @callback list_emitters() :: list(emitter_id)
  @callback started?(emitter_id) :: boolean()
  @callback restart(emitter_id) :: :ok | {:error, term()}
end
