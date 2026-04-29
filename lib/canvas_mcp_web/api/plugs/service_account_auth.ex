defmodule CanvasMcpWeb.Api.Plugs.ServiceAccountAuth do
  @moduledoc """
  Plug that authenticates API requests via Bearer service account tokens.
  Assigns :api_user (the linked User struct) and :service_account_id to the conn.
  """
  import Plug.Conn
  alias CanvasMcp.Data.ServiceAccount
  alias CanvasMcp.Data.User
  alias CanvasMcp.UserActor

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> raw_token] <- get_req_header(conn, "authorization"),
         {:ok, sa} <- ServiceAccount.get_by_token(raw_token),
         {:ok, user} <- User.get_by_id(sa["user_id"]),
         {:ok, _pid} <- UserActor.ensure_started(user.id) do
      conn
      |> assign(:api_user, user)
      |> assign(:service_account_id, sa["id"])
    else
      _ -> unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      401,
      Jason.encode!(%{error: "unauthorized", message: "Invalid or missing API token"})
    )
    |> halt()
  end
end
