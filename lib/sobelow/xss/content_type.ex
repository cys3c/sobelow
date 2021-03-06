defmodule Sobelow.XSS.ContentType do
  @moduledoc """
  # XSS in `put_resp_content_type`

  If an attacker is able to set arbitrary content types for an
  HTTP response containing user input, the attacker is likely to
  be able to leverage this for cross-site scripting (XSS).

  For example, consider an endpoint that returns JSON with user
  input:

      {"json": "user_input"}

  If an attacker can control the content type set in the HTTP
  response, they can set it to "text/html" and update the
  JSON to the following in order to cause XSS:

      {"json": "<script>alert(document.domain)</script>"}

  Content Type checks can be ignored with the following command:

      $ mix sobelow -i XSS.ContentType
  """
  alias Sobelow.Utils
  use Sobelow.Finding

  def run(fun, filename) do
    severity = if String.ends_with?(filename, "_controller.ex"), do: false, else: :low
    {vars, params, {fun_name, [{_, line_no}]}} = parse_def(fun)

    Enum.each vars, fn var ->
      add_finding(line_no, filename, fun_name,
                  fun, var, Utils.get_sev(params, var, severity))
    end
  end

  ## put_resp_content_type(conn, content_type, charset \\ "utf-8")
  def parse_def(fun) do
    {vars, params, {fun_name, line_no}} = Utils.get_fun_vars_and_meta(fun, 1, :put_resp_content_type)
    {aliased_vars,_,_} = Utils.get_fun_vars_and_meta(fun, 1, :put_resp_content_type, [:Plug, :Conn])

    {vars ++ aliased_vars, params, {fun_name, line_no}}
  end


  def add_finding(line_no, filename, fun_name, fun, var, severity) do
    Utils.add_finding(line_no, filename, fun,
                      fun_name, var, severity,
                      "XSS in `put_resp_content_type`", :put_resp_content_type, [:Plug, :Conn])
  end
end