defmodule GitlockPhxWeb.LandingController do
  use GitlockPhxWeb, :controller

  plug :put_root_layout, html: {GitlockPhxWeb.Layouts, :landing_root}
  plug :put_layout, false

  def index(conn, _params) do
    render(conn, :index)
  end
end
