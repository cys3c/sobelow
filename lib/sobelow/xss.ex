defmodule Sobelow.XSS do
  alias Sobelow.Utils

  def reflected_xss() do
    path = "../hexpm/lib/hexpm/web/controllers/login_controller.ex"
    def_fun = Utils.get_def_funs(path)
    |> Enum.map(&Utils.parse_fun/1)

    Utils.parse_fun(def_fun)
  end
end