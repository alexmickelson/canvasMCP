defmodule CanvasMcpWeb.Router do
  use CanvasMcpWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CanvasMcpWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_admin do
    plug :require_admin_user
  end

  pipeline :require_authenticated do
    plug :require_authenticated_user
  end

  scope "/", CanvasMcpWeb.Home do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/", CanvasMcpWeb.App do
    pipe_through [:browser, :require_authenticated]

    live_session :authenticated,
      on_mount: [] do
      live "/app", HomeLive
      live "/app/profile", ProfileLive
      live "/app/courses/:course_id", Courses.CourseLive
      live "/app/courses/:course_id/assignments/:id", Courses.AssignmentLive
    end
  end

  scope "/admin", CanvasMcpWeb.Admin do
    pipe_through [:browser, :require_admin]

    live_session :admin,
      on_mount: [] do
      live "/", AuditLogLive
    end
  end

  scope "/auth", CanvasMcpWeb do
    pipe_through :browser

    get "/login", AuthController, :authorize
    get "/callback", AuthController, :callback
    get "/logout", AuthController, :logout
  end

  # Other scopes may use custom stacks.
  # scope "/api", CanvasMcpWeb do
  #   pipe_through :api
  # end

  if Application.compile_env(:canvas_mcp, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CanvasMcpWeb.Telemetry
    end
  end

  defp require_authenticated_user(conn, _opts) do
    if get_session(conn, "current_user") do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "You must be logged in to access this page.")
      |> Phoenix.Controller.redirect(to: "/")
      |> halt()
    end
  end

  defp require_admin_user(conn, _opts) do
    user = get_session(conn, "current_user")

    if user && user.is_admin do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "You must be an admin to access this page.")
      |> Phoenix.Controller.redirect(to: "/")
      |> halt()
    end
  end
end
