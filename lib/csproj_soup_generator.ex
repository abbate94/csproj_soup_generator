defmodule CSProjSOUPGenerator do
  @package_header "SOUP Title"
  @package_header_length String.length(@package_header)
  @link_header "Origin (e.g. GitHub location)"
  @link_header_length String.length(@link_header)
  @version_header "Version"
  @version_header_length String.length(@version_header)

  @spec generate(binary(), binary(), boolean(), boolean()) :: :ok
  def generate(root_dir, output_file_path, recurse, summarize) do
    root_dir
    |> find_csproj_files(recurse)
    |> Enum.map(&{String.trim_leading(&1, "#{root_dir}/"), parse_packages_in_csproj(&1)})
    |> process_files(summarize)
    |> write_result(output_file_path)
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

  defp parse_packages_in_csproj(file_path) do
    file_path
    |> File.read!()
    |> String.split("\n")
    |> Enum.map(&String.trim_leading/1)
    |> Enum.map(&Regex.run(~r/<PackageReference.*Include="(.+)".*Version="(.+)"/i, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn [_, name, version] -> {name, version, nuget_org_link(name, version)} end)
  end

  defp nuget_org_link(package_name, package_version),
    do: "https://www.nuget.org/packages/#{package_name}/#{package_version}"

  defp process_files(parsed_files, false) do
    Enum.map(parsed_files, fn {filename, packages} ->
      {filename, Enum.sort(packages, &package_sorter/2)}
    end)
  end

  defp process_files(parsed_files, true) do
    {filenames, packages} = Enum.unzip(parsed_files)

    packages =
      packages
      |> List.flatten()
      |> Enum.uniq_by(fn {name, version, _} -> "#{String.downcase(name)}#{version}" end)
      |> Enum.sort(&package_sorter/2)

    {Enum.sort(filenames), packages}
  end

  defp package_sorter({name, a_version, _}, {name, b_version, _}) when a_version <= b_version,
    do: true

  defp package_sorter({a_name, _, _}, {b_name, _, _}),
    do: String.downcase(a_name) <= String.downcase(b_name)

  defp write_result({filenames, packages}, output_file_path) do
    {Enum.join(filenames, "\n"), packages}
    |> build_result_string()
    |> then(&File.write!(output_file_path, &1))
  end

  defp write_result(parsed_files, output_file_path) do
    parsed_files
    |> Enum.map(&build_result_string/1)
    |> Enum.join("\n")
    |> then(&File.write!(output_file_path, &1))
  end

  defp build_result_string({header, packages}) do
    {longest_name, _, _} = Enum.max_by(packages, fn {n, _, _} -> String.length(n) end)
    {_, longest_version, _} = Enum.max_by(packages, fn {_, v, _} -> String.length(v) end)
    {_, _, longest_link} = Enum.max_by(packages, fn {_, _, l} -> String.length(l) end)

    max_name_length = longest_name |> String.length() |> max(@package_header_length)
    max_version_length = longest_version |> String.length() |> max(@version_header_length)
    max_link_length = longest_link |> String.length() |> max(@link_header_length)

    """
    #{header}
    #{:io_lib.format("| ~*s | ~*s | ~*s |", [-max_name_length, @package_header, -max_link_length, @link_header, -max_version_length, @version_header])}
    #{:io_lib.format("|-~*c-|-~*c-|-~*c-|", [-max_name_length, ?-, -max_link_length, ?-, -max_version_length, ?-])}
    #{Enum.map(packages, fn {name, version, link} -> :io_lib.format("| ~*s | ~*s | ~*s |~n", [-max_name_length, name, -max_link_length, link, -max_version_length, version]) end)}
    """
  end
end
