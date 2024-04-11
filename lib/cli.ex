defmodule CSprojSOUPGenerator.CLI do
  defp options_config() do
    [
      strict: [
        recursive: :boolean,
        out: :string,
        help: :boolean
      ],
      aliases: [
        r: :recursive,
        o: :out,
        h: :help
      ]
    ]
  end

  defp options_defaults() do
    [
      recursive: false,
      out: "soups.md"
    ]
  end

  def main(args) do
    args
    |> OptionParser.parse(options_config())
    |> execute()
  end

  defp execute({opts, [input_dir], []}) do
    if opts[:help] do
      print_help()
    else
      input_dir = String.trim_trailing(input_dir, "/")

      opts
      |> Keyword.merge(options_defaults(), fn _, v1, _ -> v1 end)
      |> then(&CSprojSOUPGenerator.generate(input_dir, &1[:out], &1[:recursive]))
    end
  end

  defp execute({_, _, flag_errors}) do
    for {k, _} <- flag_errors, do: IO.puts("Error with flag #{k}\n")

    print_help()
  end

  defp print_help() do
    defaults = options_defaults()

    """
    Generates a Markdown report of SOUPs for C# project files in <input directory>

    Usage: #{:escript.script_name()} <options> <input directory>

    Options:
        -r|--recursive      Recursively search the input directory for .csproj files. Default: #{defaults[:recursive]}
        -o|--out <name>     Define the name of the output file. Default: #{defaults[:out]}
        -h|--help           Show this help
    """
    |> IO.puts()
  end
end
