defmodule Sobelow.Traversal.FileModule do
  alias Sobelow.Utils
  use Sobelow.Finding
  @file_funcs [:read,
               :read!,
               :write,
               :write!,
               :rm,
               :rm!,
               :rm_rf]

  @double_file_funcs [:cp,
                      :cp!,
                      :cp_r,
                      :cp_r!,
                      :ln,
                      :ln!,
                      :ln_s,
                      :ln_s!]

  def run(fun, filename) do
    severity = if String.ends_with?(filename, "_controller.ex"), do: false, else: :low

    Enum.each @file_funcs ++ @double_file_funcs, fn(file_func) ->
      {vars, params, {fun_name, [{_, line_no}]}} = parse_def(fun, file_func)
      Enum.each vars, fn var ->
        add_finding(line_no, filename, fun_name,
                    fun, var, file_func,
                    Utils.get_sev(params, var, severity))
      end
    end

    Enum.each @double_file_funcs, fn(file_func) ->
      {vars, params, {fun_name, [{_, line_no}]}} = parse_second_def(fun, file_func)
      Enum.each vars, fn var ->
        add_finding(line_no, filename, fun_name,
                    fun, var, file_func,
                    Utils.get_sev(params, var, severity))
      end
    end
  end

  def parse_def(fun, type) do
    Utils.get_fun_vars_and_meta(fun, 0, type, [:File])
  end

  def parse_second_def(fun, type) do
    Utils.get_fun_vars_and_meta(fun, 1, type, [:File])
  end

  def add_finding(line_no, filename, fun_name, fun, var, type, severity) do
    title = "Directory Traversal in `File.#{type}`"
    Utils.add_finding(line_no, filename, fun,
                      fun_name, var, severity,
                      title, type, [:File])
  end

  def details() do
    Sobelow.Traversal.details()
  end
end