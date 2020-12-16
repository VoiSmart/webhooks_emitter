defmodule WebhooksEmitter.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :webhooks_emitter,
      description: "Emits your events as outgoing http webhooks.",
      source_url: "https://github.com/VoiSmart/webhooks_emitter",
      homepage_url: "https://github.com/VoiSmart/webhooks_emitter",
      version: "0.2.0",
      elixir: "~> 1.10",
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {WebhooksEmitter.Application, []}
    ]
  end

  defp package do
    [
      mantainers: ["Matteo Brancaleoni"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/VoiSmart/webhooks_emitter"}
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      nest_modules_by_prefix: [WebhooksEmitter, Emitter.JsonSafeEncoder]
    ]
  end

  defp deps do
    [
      {:httpoison, "~> 1.7"},
      {:jason, "~> 1.1"},
      {:elixir_uuid, "~> 1.2"},
      {:gen_state_machine, "~> 3.0"},
      {:backoff, "~> 1.1"},
      # devel stuff
      {:hammox, "~> 0.3", only: :test},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:excoveralls, "~> 0.13", only: :test},
      {:stream_data, "~> 0.5", only: :test}
    ]
  end
end
