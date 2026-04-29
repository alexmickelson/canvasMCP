defmodule CanvasMcpWeb.Api.OpenApiController do
  use CanvasMcpWeb, :controller

  alias CanvasMcpWeb.Api.OpenApi

  @doc "GET /api/openapi.json — serves the OpenAPI 3.1 spec for this API"
  def spec(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(OpenApi.build(base_url(conn)), pretty: true))
  end

  defp base_url(conn) do
    scheme = if conn.scheme == :https, do: "https", else: "http"

    port_suffix =
      cond do
        conn.scheme == :https and conn.port == 443 -> ""
        conn.scheme == :http and conn.port == 80 -> ""
        true -> ":#{conn.port}"
      end

    "#{scheme}://#{conn.host}#{port_suffix}"
  end
end
