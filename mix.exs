defmodule Aegis.MixProject do
  use Mix.Project

  def project do
    [
      app: :aegis,
      version: "1.0.0",
      elixir: "~> 1.18.4-otp-28",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      description: description(),
      dialyzer: [ignore_warnings: ".dialyzer_ignore.exs"],
      package: package(),
      source_url: "https://github.com/lorenzo-sf/aegis",
      homepage_url: "https://hex.pm/packages/aegis",
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md", "LICENSE"],
        source_ref: "v1.0.0",
        source_url: "https://github.com/lorenzo-sf/aegis"
      ],
      escript: [main_module: Aegis.CLI]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools, :argos, :aurora]
    ]
  end

  defp aliases do
    [
      gen: [
        "escript.build",
        "deploy"
      ],
      deploy: fn _ ->
        dest_dir = Path.expand("~/.Ypsilon")
        File.mkdir_p!(dest_dir)
        File.cp!("aegis", Path.join(dest_dir, "aegis"))
        IO.puts("✅ Escript instalado en #{dest_dir}/aegis")
      end,
      credo: ["format --check-formatted", "credo --strict --format=oneline"],
      quality: [
        "deps.get",
        "clean",
        "compile --warnings-as-errors",
        "cmd MIX_ENV=test mix test",
        "credo --strict",
        "dialyzer",
        "cmd 'echo \\\"quality terminado\"'"
      ],
      ci: [
        "deps.get",
        "clean",
        "compile --warnings-as-errors",
        "cmd MIX_ENV=test mix test",
        "credo --strict",
        "cmd 'echo \\\"terminado terminado\"'"
      ],
      hex_prepare: [
        "clean",
        "compile --force --warnings-as-errors",
        "format",
        "test",
        "docs",
        "cmd mix hex.build"
      ],
      hex_publish: [
        "hex_prepare",
        "cmd mix hex.publish"
      ]
    ]
  end

  defp deps do
    [
      # Core dependencies - Proyecto Ypsilon
      # Level 1A - Aurora (formatting & rendering)
      # Use for published version
      # {:aurora, "~> 1.0.4"},
      {:aurora, path: "../Aurora"},
      # Level 1B - Argos (command execution & task orchestration)
      {:argos, path: "../Argos"},

      # JSON handling
      {:jason, "~> 1.4"},

      # Development dependencies
      {:credo, "~> 1.7.12", only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.3", only: :dev},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.34", runtime: false},
      {:mix_test_watch, "~> 1.1", only: :dev, runtime: false},

      # Test dependencies
      {:propcheck, "~> 1.4", only: :test}
    ]
  end

  def escript do
    [
      main_module: Aegis.CLI
    ]
  end

  defp description do
    "Un potente framework en Elixir para crear aplicaciones CLI y TUI ricas en funcionalidades, con menús interactivos, animaciones y control avanzado del terminal. Construido sobre Aurora y Pandr."
  end

  defp package do
    [
      name: "aegis",
      licenses: ["Apache-2.0"],
      maintainers: ["Lorenzo Sánchez Fraile"],
      links: %{
        "GitHub" => "https://github.com/lorenzo-sf/aegis",
        "Docs" => "https://hexdocs.pm/aegis",
        "Changelog" => "https://github.com/lorenzo-sf/aegis/blob/main/CHANGELOG.md"
      },
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE .dialyzer_ignore.exs)
    ]
  end
end
