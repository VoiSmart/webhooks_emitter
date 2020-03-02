defmodule WebhooksEmitter.Emitter.WorkerTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import Hammox
  import ExUnit.CaptureLog

  alias __MODULE__.HTTPMock
  alias WebhooksEmitter.Config
  alias WebhooksEmitter.Emitter.HttpClient
  alias WebhooksEmitter.Emitter.Worker

  setup_all do
    Mox.defmock(__MODULE__.HTTPMock, for: HttpClient)

    :ok
  end

  # setup :set_mox_global

  test "start_link/1" do
    opts = [
      config: %Config{url: "http://foo.bar"},
      event_names: [:an_event]
    ]

    assert {:ok, pid} = Worker.start_link(opts)
    assert is_pid(pid)
  end

  describe "emit/4" do
    test "emits an event" do
      {:ok, pid} = start_worker()

      event_name = :an_event
      payload = %{foo: "bar"}

      myself = self()
      ref = make_ref()

      HTTPMock
      |> expect(:do_post, 1, fn ^event_name, ^payload, _config, "baz" ->
        send(myself, {:ok, ref})

        success_response()
      end)

      :ok = Worker.emit(pid, event_name, payload, "baz")

      assert_receive {:ok, ^ref}, 1000
    end

    test "does not log the secret on error" do
      {:ok, pid} = start_worker("supersecret")

      event_name = :an_event
      payload = %{foo: "bar"}

      myself = self()
      ref = make_ref()

      HTTPMock
      |> expect(:do_post, 3, fn ^event_name, ^payload, _config, "baz" ->
        send(myself, ref)

        error_response()
      end)

      assert capture_log(fn ->
               :ok = Worker.emit(pid, event_name, payload, "baz")
               assert_receive ^ref, 1000
               assert_receive ^ref, 1000
               assert_receive ^ref, 1000
               refute_receive ^ref
             end) =~ "redacted"
    end

    @tag capture_log: true
    test "retries 3 times (default) on failure" do
      {:ok, pid} = start_worker()

      event_name = :an_event
      payload = %{foo: "bar"}

      myself = self()
      ref = make_ref()

      HTTPMock
      |> expect(:do_post, 3, fn ^event_name, ^payload, _config, "baz" ->
        send(myself, {:ok, ref})

        http_error_response()
      end)

      :ok = Worker.emit(pid, event_name, payload, "baz")

      assert_receive {:ok, ^ref}, 1000
      assert_receive {:ok, ^ref}, 1000
      assert_receive {:ok, ^ref}, 1000
      refute_receive {:ok, ^ref}
    end

    @tag capture_log: true
    test "after max retries, event is discarded" do
      {:ok, pid} = start_worker()

      myself = self()

      HTTPMock
      |> expect(:do_post, 4, fn event_name, payload, _config, "baz" ->
        send(myself, {:ok, event_name, payload})

        http_error_response()
      end)

      :ok = Worker.emit(pid, :first_event, %{}, "baz")

      assert_receive {:ok, :first_event, _}, 1000
      assert_receive {:ok, :first_event, _}, 1000
      assert_receive {:ok, :first_event, _}, 1000

      :ok = Worker.emit(pid, :second_event, %{}, "baz")
      assert_receive {:ok, :second_event, _}, 1000
    end

    @tag capture_log: true
    test "event succeed after some failures" do
      {:ok, pid} = start_worker()

      ref = make_ref()
      myself = self()

      HTTPMock
      |> expect(:do_post, 3, fn :event_name, _payload, _config, "baz" ->
        send(myself, {:ok, ref, self()})

        receive do
          :fail -> http_error_response()
          :success -> success_response()
        end
      end)

      :ok = Worker.emit(pid, :event_name, %{}, "baz")

      assert_receive {:ok, ^ref, task}, 1000
      send(task, :fail)

      assert_receive {:ok, ^ref, task}, 1000
      send(task, :success)

      refute_receive {:ok, ^ref, _task}
    end

    @tag capture_log: true
    test "delivery is retried on underlying lib error" do
      {:ok, pid} = start_worker()

      event_name = :an_event
      payload = %{foo: "bar"}

      myself = self()
      ref = make_ref()

      HTTPMock
      |> expect(:do_post, 3, fn ^event_name, ^payload, _config, "baz" ->
        send(myself, {:ok, ref})

        error_response()
      end)

      :ok = Worker.emit(pid, event_name, payload, "baz")

      assert_receive {:ok, ^ref}, 1000
      assert_receive {:ok, ^ref}, 1000
      assert_receive {:ok, ^ref}, 1000
      refute_receive {:ok, ^ref}
    end

    @tag capture_log: true
    test "multiple messages are not interleaved during retries" do
      {:ok, pid} = start_worker()

      ref = make_ref()
      myself = self()

      HTTPMock
      |> expect(:do_post, 3, fn :event_name, payload, _config, "baz" ->
        send(myself, {:ok, ref, self(), payload})

        receive do
          :fail -> http_error_response()
          :success -> success_response()
        end
      end)

      :ok = Worker.emit(pid, :event_name, %{first: true}, "baz")
      assert_receive {:ok, ^ref, task, _}, 1000
      send(task, :fail)

      :ok = Worker.emit(pid, :event_name, %{second: true}, "baz")

      assert_receive {:ok, ^ref, task, %{first: true}}, 1000
      send(task, :success)

      assert_receive {:ok, ^ref, task, %{second: true}}, 1000
      send(task, :succeed)

      refute_receive {:ok, ^ref, _task}
    end
  end

  defp start_worker(secret \\ nil) do
    opts = [
      config: %Config{
        url: "http://foo.bar",
        backoff_start: 1,
        backoff_limit: 10,
        http_client: HTTPMock,
        secret: secret
      },
      event_names: [:an_event]
    ]

    {:ok, pid} = Worker.start_link(opts)
    allow(HTTPMock, self(), pid)

    {:ok, pid}
  end

  defp success_response do
    {:ok, %{status_code: 200}}
  end

  defp http_error_response do
    {:ok, %{status_code: 500}}
  end

  defp error_response do
    {:error, :internal_error}
  end
end
