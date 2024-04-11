defmodule CSprojSOUPGenerator.MixProject do
  use Mix.Project

  def project do
    [
      app: :csproj_soup_generator,
      version: "0.1.0",
      escript: escript()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application, do: [extra_applications: [:logger]]

  def escript, do: [main_module: CSprojSOUPGenerator.CLI]
end
