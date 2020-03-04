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

  @callback attach(emitter_id, event_name, emitter_config) :: :ok | {:error, :already_exists}
  @callback attach_many(emitter_id, event_names, emitter_config) ::
              :ok | {:error, :already_exists}
  @callback detach(emitter_id) :: :ok
  @callback emit(event_name, event_payload, request_id) :: {:ok, request_id}
end
