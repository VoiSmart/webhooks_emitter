# WebhooksEmitter

[![Build Status](https://travis-ci.org/VoiSmart/webhooks_emitter.svg)](https://travis-ci.org/VoiSmart/webhooks_emitter) 
[![Coverage Status](https://coveralls.io/repos/github/VoiSmart/webhooks_emitter/badge.svg?branch=develop)](https://coveralls.io/github/VoiSmart/webhooks_emitter?branch=develop)

> Emits your events as outgoing http webhooks.

WebhooksEmitter takes care of emitting your events with an HTTP POST to remote listeners. Tries to be non-blocking as much as possible,
by queuing events even during the HTTP operation or backoff intervals. Handles retries and timeouts for you. Is capable to digital sign the payload,
with a configurable secret, in order to check the message integrity on the receiver side.

## Installation

The package can be installed by adding `webhooks_emitter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:webhooks_emitter, "~> 0.1.0"}
  ]
end
```

## Usage

To start, a new configuration must be built using `WebhooksEmitter.Config.new/1`:

```elixir
iex> config = WebhooksEmitter.Config.new("https://your.end.point")
```

Then attach a new handler for the above config, using `WebhooksEmitter.attach/3` to some event:

```elixir
iex> :ok = WebhooksEmitter.attach(:my_emitter, :some_event, config)
```

if the emitter id is already used, an error is returned:

```elixir
iex> {:error, :already_exists} = WebhooksEmitter.attach(:already_used_id, :some_event, config)
```

Is possible to attach the same config to a list of events, using `WebhooksEmitter.attach_many/3`.

When your event is ready for dispatch, just call `WebhooksEmitter.emit/3`, with the payload and an optional request id, that will be added to the http request headers:

```elixir
iex> {ok, request_id} = WebhooksEmitter.emit(:some_event, %{data: "foobar"}, "an_optional_request_id")
```

if the above request id is not passed, a new one will be automatically generated.

To detach an emitter, just call `WebhooksEmitter.detach/1` with your attached emitter id:

```elixir
iex> :ok = WebhooksEmitter.detach(:my_emitter)
```

Anatomy of an HTTP request performed by the emitter:

```
POST /hooks/ah7Ahtet6abohbai HTTP/1.1
Host: localhost:1234
X-Webhooks-Event: averyimportantevent
X-Webhooks-Delivery: fbc7fbe7-2e9b-4911-a50f-e0452672192c
X-Webhooks-Signature: sha256:2vu2rb2moi6dihmlm6tvd3nbdnahjncmus9p8pl76h3v4ub054h0
User-Agent: WebHooks-Emitter/0.1.0
Content-Type: application/json
Content-Length: 6615

{
  "message": "thank you for all the fish",
  ...
}
```

## License

Copyright 2020 Matteo Brancaleoni and VoiSmart S.R.L.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

[documentation]: https://hexdocs.pm/webhooks_emitter
