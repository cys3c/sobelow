defmodule Sobelow.XSS.Raw do
  alias Sobelow.Utils
  use Sobelow.Finding

  def run(fun, filename, _, nil) do
    if String.ends_with?(filename, "_view.ex") do
      {vars, params, {fun_name, [{_, line_no}]}} = parse_raw_def(fun)
      Enum.each vars, fn var ->
        if Enum.member?(params, var) || var === "conn.params" do
          print_view_finding(line_no, filename, fun_name, fun, var, :medium)
        else
          print_view_finding(line_no, filename, fun_name, fun, var, :low)
        end
      end
    end
  end

  def run(fun, filename, web_root, controller) do
    {vars, _, {fun_name, [{_, line_no}]}} = parse_render_def(fun)
    root = if String.ends_with?(web_root, "/lib/") do
      app_name = Sobelow.get_env(:app_name)
      prc = web_root <> app_name <> "_web/"
      rc = web_root <> app_name <> "/web/"
      Enum.find([rc, prc], "", &File.exists?/1)
    else
      web_root
    end

    Enum.each vars, fn {template, ref_vars, vars} ->
      template =
        cond do
          is_atom(template) -> Atom.to_string(template) <> ".html"
          is_binary(template) -> template
          true -> ""
        end

      template_path = root <> "templates/" <> controller <> "/" <> template <> ".eex"
      if File.exists?(template_path) do
        raw_vals = Utils.get_template_raw_vars(template_path)
        Enum.each(ref_vars, fn var ->
          if Enum.member?(raw_vals, var) do
            t_name = String.replace_prefix(Path.expand(template_path, ""), "/", "")
            add_finding(t_name, line_no, filename, fun_name, fun, var, :high)
          end
        end)

        Enum.each(vars, fn var ->
          if Enum.member?(raw_vals, var) do
            t_name = String.replace_prefix(Path.expand(template_path, ""), "/", "")
            add_finding(t_name, line_no, filename, fun_name, fun, var, :medium)
          end
        end)
      end
    end
  end

  def parse_render_def(fun) do
    {params, {fun_name, line_no}} = Utils.get_fun_declaration(fun)

    pipefuns = Utils.get_pipe_funs(fun)
    |> Enum.map(fn {_, _, opts} -> Enum.at(opts, 1) end)
    |> Enum.flat_map(&Utils.get_funs_of_type(&1, :render))

    pipevars = pipefuns
    |> Enum.map(&Utils.parse_render_opts(&1, params, 0))
    |> List.flatten

    vars = Utils.get_funs_of_type(fun, :render) -- pipefuns
    |> Enum.map(&Utils.parse_render_opts(&1, params, 1))

    {vars ++ pipevars, params, {fun_name, line_no}}
  end

  def parse_raw_def(fun) do
    Utils.get_fun_vars_and_meta(fun, 0, :raw)
  end

  def details() do
    Sobelow.XSS.details()
  end

  defp add_finding(t_name, line_no, filename, fun_name, fun, var, severity) do
    type = "XSS"
    case Sobelow.format() do
      "json" ->
        finding = [
          type: type,
          file: filename,
          function: "#{fun_name}:#{line_no}",
          variable: "@#{var}",
          template: "#{t_name}"
        ]
        Sobelow.log_finding(finding, severity)
      "txt" ->
        Sobelow.log_finding(type, severity)

        IO.puts Utils.finding_header(type, severity)
        IO.puts Utils.finding_file_metadata(filename, fun_name, line_no)
        IO.puts "Template: #{t_name} - @#{var}"
        if Sobelow.get_env(:with_code), do: Utils.print_code(fun, var, :render)
        IO.puts Utils.finding_break()
      "compact" ->
        Utils.log_compact_finding(type, filename, line_no, severity)
      _ ->
        Sobelow.log_finding(type, severity)
    end
  end

  defp print_view_finding(line_no, filename, fun_name, fun, var, severity) do
    Utils.add_finding(line_no, filename, fun,
                      fun_name, var, severity,
                      "XSS", :raw)
  end
end