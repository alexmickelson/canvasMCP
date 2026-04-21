defmodule CanvasMcpWeb.PageController do
  use CanvasMcpWeb, :controller

  def home(conn, _params) do
    claims = get_session(conn, "oidc_claims")
    render(conn, :home, claims: claims)
  end
end
