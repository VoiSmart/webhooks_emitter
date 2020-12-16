defmodule WebhooksEmitterTest do
  @moduledoc false
  use ExUnit.Case

  alias WebhooksEmitter.{Config, Emitter}

  setup do
    on_exit(fn ->
      WebhooksEmitter.detach(:myid)
    end)
  end

  describe "attach/3" do
    test "attaches a new emitter" do
      res = WebhooksEmitter.attach(:myid, "an_event", %Config{url: "http://foo.bar"})

      assert :ok = res
    end

    test "errors on a duplicated emitter id " do
      WebhooksEmitter.attach(:myid, "an_event", %Config{url: "http://foo.bar"})
      res = WebhooksEmitter.attach(:myid, "an_event", %Config{url: "http://foo.bar"})

      assert {:error, :already_exists} = res
    end

    test "different emitters can handle same events" do
      res1 = WebhooksEmitter.attach(:myid1, "an_event", %Config{url: "http://foo.bar"})
      res2 = WebhooksEmitter.attach(:myid2, "an_event", %Config{url: "http://foo.bar"})

      assert :ok = res1
      assert :ok = res2
    end
  end

  describe "emit/3" do
    test "emits an event w/o request id" do
      event = :my_event
      subscribe_registry(event)

      assert {:ok, rq_id} = WebhooksEmitter.emit(event, %{foo: "bar"})
      assert is_binary(rq_id)

      assert_receive {_, {:emit, ^event, %{foo: "bar"}, ^rq_id}}
    end
  end

  describe "list_emitters/0" do
    test "retrieve emitter ID attached to events" do
      WebhooksEmitter.attach(:myid4, "an_event", %Config{url: "http://foo.bar"})
      assert :myid4 in WebhooksEmitter.list_emitters()
    end
  end

  describe "started?/1" do
    test "with an already started emitter ID" do
      WebhooksEmitter.attach(:myid5, "an_event", %Config{url: "http://foo.bar"})
      assert WebhooksEmitter.started?(:myid5)
    end

    test "with a not started emitter ID" do
      refute WebhooksEmitter.started?(:not_existent_id)
    end
  end

  defp subscribe_registry(event_name) do
    Registry.register(Emitter.registry_name(), event_name, [])
  end
end
