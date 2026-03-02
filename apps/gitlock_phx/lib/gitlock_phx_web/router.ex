defmodule GitlockPhxWeb.Router do
  use GitlockPhxWeb, :router

  import GitlockPhxWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GitlockPhxWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GitlockPhxWeb do
    pipe_through :browser

    get "/", LandingController, :index
    get "/app", PageController, :home
  end

  scope "/", GitlockPhxWeb do
    pipe_through [:browser]

    live_session :app,
      on_mount: [{GitlockPhxWeb.UserAuth, :mount_current_scope}] do
      live "/analyze", AnalyzeLive
      live "/workflows", WorkflowLive
      live "/workflows/:id", WorkflowLive
      live "/pipelines", PipelinesLive
      live "/runs", RunsLive
      live "/runs/:id", RunDetailLive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", GitlockPhxWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:gitlock_phx, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GitlockPhxWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", GitlockPhxWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{GitlockPhxWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", GitlockPhxWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{GitlockPhxWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
