defmodule WebhooksEmitter.Emitter.HttpClient do
  @moduledoc false
  alias WebhooksEmitter.Config

  @type event_name :: atom() | String.t()
  @type payload :: map()
  @type config :: Config.t()
  @type request_id :: String.t()

  @type response :: {:ok, %{status_code: non_neg_integer()}} | {:error, any()}

  @callback do_post(
              event_name,
              payload,
              config,
              request_id
            ) :: response

  @app_version Mix.Project.config() |> Keyword.fetch!(:version)

  @doc false
  def default_ua do
    <<"WebHooks-Emitter/", @app_version::binary>>
  end
end
