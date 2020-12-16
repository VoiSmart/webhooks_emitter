defmodule WebhooksEmitter.Emitter do
  @moduledoc false
  alias WebhooksEmitter.Emitter.Supervisor, as: EmitterSup
  alias WebhooksEmitter.Emitter.Worker

  def registry_name do
    WebhooksEmitter.EmittersRegistry
  end

  def start_emitter(emitter_id, event_names, config) do
    spec = %{
      id: emitter_spec_id(emitter_id),
      start: {Worker, :start_link, [[event_names: event_names, config: config]]},
      restart: :transient
    }

    Supervisor.start_child(EmitterSup, spec)
  end

  def terminate_emitter(emitter_id) do
    Supervisor.terminate_child(EmitterSup, emitter_spec_id(emitter_id))
    Supervisor.delete_child(EmitterSup, emitter_spec_id(emitter_id))
  end

  def stop_emitter(emitter_id) do
    Supervisor.terminate_child(EmitterSup, emitter_spec_id(emitter_id))
  end

  def restart_emitter(emitter_id) do
    Supervisor.restart_child(EmitterSup, emitter_spec_id(emitter_id))
  end

  def get_emitters do
    EmitterSup
    |> Supervisor.which_children()
    |> Enum.filter(fn
      {_id, child, _, _} when is_pid(child) -> true
      _ -> false
    end)
    |> Enum.map(fn {{_, emitter_id}, _, _, _} -> emitter_id end)
  end

  def emit(event_name, payload, request_id) do
    registry_name()
    |> Registry.dispatch(
      event_name,
      {__MODULE__, :dispatch, [event_name, payload, request_id]}
    )
  end

  def dispatch(listeners, event_name, payload, request_id) do
    for {pid, _} <- listeners do
      Worker.emit(pid, event_name, payload, request_id)
    end
  end

  defp emitter_spec_id(emitter_id) do
    {Worker, emitter_id}
  end
end
