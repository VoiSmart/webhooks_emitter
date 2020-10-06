defmodule WebhooksEmitter.Emitter.Worker do
  @moduledoc false
  use GenStateMachine

  alias WebhooksEmitter.{Config, Emitter}
  alias WebhooksEmitter.Emitter.Queue

  require Logger

  def start_link(opts) do
    GenStateMachine.start_link(__MODULE__, opts)
  end

  def emit(server, event_name, payload, request_id) do
    GenStateMachine.cast(server, {:emit, event_name, payload, request_id})
  end

  defmodule Data do
    @moduledoc false
    defstruct config: nil, events_q: nil, worker_task: nil, backoff: nil
  end

  defmodule Request do
    @moduledoc false
    defstruct config: nil, event_name: nil, payload: nil, request_id: nil, retry_nr: 0
  end

  @impl true
  def init(opts) do
    %Config{} = config = Keyword.fetch!(opts, :config)

    Keyword.fetch!(opts, :event_names) |> subscribe()

    backoff = :backoff.init(config.backoff_start, config.backoff_limit)

    {:ok, :idle,
     %Data{
       config: config,
       events_q: Queue.new(),
       backoff: backoff |> :backoff.type(:jitter)
     }}
  end

  @impl true
  def handle_event(:cast, {:emit, event_name, payload, request_id}, :idle, data) do
    %{config: config, events_q: q} = data

    rq = %Request{
      config: config,
      event_name: event_name,
      payload: payload,
      request_id: request_id
    }

    %{data | events_q: Queue.put(q, rq)} |> handle_idle
  end

  @impl true
  def handle_event(:cast, {:emit, event_name, payload, request_id}, state, data)
      when state in [:running, :backoff] do
    %{config: config, events_q: q} = data

    rq = %Request{
      config: config,
      event_name: event_name,
      payload: payload,
      request_id: request_id
    }

    {:keep_state, %{data | events_q: Queue.put(q, rq)}}
  end

  @impl true
  def handle_event(
        :info,
        {ref, {:ok, %{status_code: sc}}},
        :running,
        %{worker_task: %{ref: ref}} = data
      )
      when sc >= 200 and sc < 300 do
    # response from task, with http status code between 200 and 299
    %{events_q: q} = data

    # remove request from queue and check if there's some more work to do
    {:ok, new_q, _} = Queue.pop_last(q)

    {_, backoff} = :backoff.succeed(data.backoff)

    %{data | worker_task: nil, events_q: new_q, backoff: backoff}
    |> handle_idle()
  end

  @impl true
  def handle_event(
        :info,
        {ref, response},
        :running,
        %{backoff: backoff, worker_task: %{ref: ref}, events_q: q} = data
      ) do
    # response from task, probably with error, reschedule it
    {:ok, _, %{request_id: rq_id}} = Queue.pop_last(q)

    Logger.warn(
      "Webhook request #{rq_id} " <>
        "got response error: #{inspect(response)}, resubmitting.",
      request_id: rq_id
    )

    timeout = :backoff.get(backoff)

    {_, new_backoff} = :backoff.fail(backoff)

    {:next_state, :backoff, %{data | worker_task: nil, backoff: new_backoff},
     [{:state_timeout, timeout, :resubmit}]}
  end

  @impl true
  # these :DOWN messages are from the spawned Task.
  # Maybe we can use them to cleanup and move the state instead of doing elsewhere?
  def handle_event(:info, {:DOWN, _, :process, _pid, :normal}, state, _data)
      when state in [:idle, :backoff, :running] do
    :keep_state_and_data
  end

  @impl true
  def handle_event(:state_timeout, :resubmit, :backoff, data) do
    handle_idle(data)
  end

  defp handle_idle(%{events_q: q} = data) do
    with {:ok, new_q, request} <- Queue.pop_last(q),
         {:ok, task, new_request} <- perform(request) do
      {:next_state, :running,
       %{data | worker_task: task, events_q: Queue.put_last(new_q, new_request)}}
    else
      {:error, :max_retries} ->
        {:ok, new_q, _} = Queue.pop_last(q)
        %{data | events_q: new_q} |> handle_idle()

      {:error, :empty} ->
        {:next_state, :idle, data}
    end
  end

  defp perform(%Request{
         config: %{max_retries: retries},
         retry_nr: retries,
         request_id: request_id
       }) do
    Logger.error(
      "Webhook request #{request_id} reached max retry, dropping message.",
      request_id: request_id
    )

    {:error, :max_retries}
  end

  defp perform(%Request{} = rq) do
    %Request{
      config: config,
      event_name: event_name,
      payload: payload,
      request_id: request_id,
      retry_nr: retry_nr
    } = rq

    t =
      Task.async(fn ->
        %{http_client: http_client} = config

        case http_client.do_post(event_name, payload, config, request_id) do
          {:ok, _} = success ->
            success

          err ->
            Logger.error(
              "Emit Error event: #{event_name}, payload: #{inspect(payload)}, " <>
                "config: #{inspect(log_config(config))}, request_id: #{request_id} " <>
                "error: #{inspect(err)}"
            )

            :error
        end
      end)

    {:ok, t, %{rq | retry_nr: retry_nr + 1}}
  end

  defp log_config(%{secret: nil} = config), do: config

  defp log_config(%{} = config) do
    Map.put(config, :secret, :redacted)
  end

  defp subscribe(event_names) do
    event_names
    |> Enum.each(fn event_name ->
      Registry.register(Emitter.registry_name(), event_name, [])
    end)
  end
end
