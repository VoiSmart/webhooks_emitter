defmodule WebhooksEmitter.Application do
  @moduledoc false
  use Application

  alias WebhooksEmitter.Emitter

  def start(_type, _args) do
    children = [
      {Registry, keys: :duplicate, name: Emitter.registry_name()},
      WebhooksEmitter.Emitter.Supervisor
    ]

    opts = [strategy: :one_for_one, name: WebhooksEmitter.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
