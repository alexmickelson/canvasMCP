defmodule CanvasMcpWeb.Home.PageController do
  use CanvasMcpWeb, :controller

  def home(conn, _params) do
    if get_session(conn, "current_user_id") do
      redirect(conn, to: ~p"/app")
    else
      render(conn, :home, [])
    end
  end
end
