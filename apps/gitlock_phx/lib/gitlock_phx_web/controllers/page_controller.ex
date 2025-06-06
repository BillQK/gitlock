defmodule GitlockPhxWeb.PageController do
  use GitlockPhxWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
