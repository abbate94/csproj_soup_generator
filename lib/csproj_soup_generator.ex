defmodule CSprojSOUPGenerator do
  @package_header "SOUP Title"
  @package_header_length String.length(@package_header)
  @link_header "Origin (e.g. GitHub location)"
  @link_header_length String.length(@link_header)
  @version_header "Version"
  @version_header_length String.length(@version_header)

  @spec generate(binary(), binary(), boolean()) :: :ok
  def generate(root_dir, output_file_path, recurse) do
    root_dir
    |> find_csproj_files(recurse)
    |> Enum.map(&process_csproj_file/1)
    |> write_results(output_file_path)
  end

  defp find_csproj_files(dir, recurse) do
    dir_content =
      dir
      |> File.ls!()
      |> Enum.map(&"#{dir}/#{&1}")

    csproj_files = Enum.filter(dir_content, &String.ends_with?(&1, ".csproj"))

    if recurse do
      dir_content
      |> Enum.filter(&File.dir?/1)
      |> Enum.flat_map(&find_csproj_files(&1, true))
      |> then(&Kernel.++(csproj_files, &1))
    else
      csproj_files
    end
  end

  defp process_csproj_file(file_path) do
    file_path
    |> File.read!()
    |> String.split("\n")
    |> Enum.map(&String.trim_leading/1)
    |> Enum.map(&Regex.run(~r/<PackageReference.*Include="(.+)".*Version="(.+)"/i, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn [_, name, version] -> {name, version, nuget_org_link(name, version)} end)
    |> build_result_string(file_path)
  end

  defp nuget_org_link(package_name, package_version),
    do: "https://www.nuget.org/packages/#{package_name}/#{package_version}"

  defp build_result_string(packages, file_path) do
    {max_name_length, max_version_length, max_link_length} =
      Enum.reduce(
        packages,
        {@package_header_length, @version_header_length, @link_header_length},
        fn {name, version, link}, {acc_name, acc_version, acc_link} ->
          {max(String.length(name), acc_name), max(String.length(version), acc_version),
           max(String.length(link), acc_link)}
        end
      )

    """
    \# #{file_path}
    #{:io_lib.format("| ~*s | ~*s | ~*s |", [-max_name_length, @package_header, -max_link_length, @link_header, -max_version_length, @version_header])}
    #{:io_lib.format("|-~*c-|-~*c-|-~*c-|", [-max_name_length, ?-, -max_link_length, ?-, -max_version_length, ?-])}
    #{Enum.map(packages, fn {name, version, link} -> :io_lib.format("| ~*s | ~*s | ~*s |~n", [-max_name_length, name, -max_link_length, link, -max_version_length, version]) end)}
    """
  end

  defp write_results(results, output_file_path),
    do: File.write!(output_file_path, Enum.join(results, "\n"))
end
