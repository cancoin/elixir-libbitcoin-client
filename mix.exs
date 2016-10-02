defmodule BitcoinClient.Mixfile do
  use Mix.Project

  def project do
    [app: :libbitcoin_client,
     version: "0.0.2",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :czmq, :base58]]
  end

  defp deps do
    [
      {:czmq, github: "gar1t/erlang-czmq"},
      {:base58, github: "cancoin/erl-base58"}
    ]
  end
end
