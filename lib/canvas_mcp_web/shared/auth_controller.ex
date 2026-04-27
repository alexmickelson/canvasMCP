defmodule CanvasMcpWeb.AuthController do
  use CanvasMcpWeb, :controller
  require Logger
  alias CanvasMcp.Data.User
  alias CanvasMcp.Data.AuditLog

  def client_id, do: Application.fetch_env!(:canvas_mcp, :oidc) |> Keyword.fetch!(:client_id)

  def callback_uri(conn) do
    default_port = URI.default_port(to_string(conn.scheme))
    port_str = if conn.port == default_port, do: "", else: ":#{conn.port}"
    "#{conn.scheme}://#{conn.host}#{port_str}/auth/callback"
  end

  @pkce_profile_opts %{require_pkce: true}

  plug :save_return_to when action in [:authorize]

  plug Oidcc.Plug.Authorize,
       [
         provider: CanvasMcp.OidcProvider,
         client_id: &__MODULE__.client_id/0,
         client_secret: :unauthenticated,
         redirect_uri: &__MODULE__.callback_uri/1,
         client_profile_opts: @pkce_profile_opts,
         scopes: ["openid", "profile", "email"]
       ]
       when action in [:authorize]

  plug Oidcc.Plug.AuthorizationCallback,
       [
         provider: CanvasMcp.OidcProvider,
         client_id: &__MODULE__.client_id/0,
         client_secret: :unauthenticated,
         redirect_uri: &__MODULE__.callback_uri/1,
         client_profile_opts: @pkce_profile_opts,
         preferred_auth_methods: [:none],
         check_peer_ip: false,
         check_useragent: false
       ]
       when action in [:callback]

  def authorize(conn, _params), do: conn

  def callback(
        %Plug.Conn{
          private: %{Oidcc.Plug.AuthorizationCallback => {:ok, {_token, userinfo}}}
        } = conn,
        _params
      ) do
    email = Map.get(userinfo, "email")

    Logger.info(
      "User login successful sub=#{Map.get(userinfo, "sub")} email=#{email} remote_ip=#{format_ip(conn.remote_ip)}"
    )

    case User.find_or_create(email) do
      {:ok, user_profile} ->
        AuditLog.record(:login_success, user_profile.id, format_ip(conn.remote_ip), %{
          sub: Map.get(userinfo, "sub"),
          email: email
        })

        return_to = get_session(conn, "return_to") || "/"

        conn
        |> delete_session("return_to")
        |> put_session("oidc_claims", userinfo)
        |> put_session("current_user_id", user_profile.id)
        |> redirect(to: return_to)

      {:error, reason} ->
        AuditLog.record(:login_failure, nil, format_ip(conn.remote_ip), %{
          email: email,
          reason: inspect(reason)
        })

        Logger.error("Failed to find_or_create user email=#{email} reason=#{inspect(reason)}")

        conn
        |> put_flash(:error, "Login failed: could not load user profile")
        |> redirect(to: ~p"/")
    end
  end

  def callback(
        %Plug.Conn{
          private: %{Oidcc.Plug.AuthorizationCallback => {:error, reason}}
        } = conn,
        _params
      ) do
    Logger.warning(
      "User login failed reason=#{inspect(reason)} remote_ip=#{format_ip(conn.remote_ip)}"
    )

    AuditLog.record(:login_failure, nil, format_ip(conn.remote_ip), %{
      reason: inspect(reason)
    })

    conn
    |> put_status(400)
    |> put_flash(:error, "Login failed: #{inspect(reason)}")
    |> redirect(to: ~p"/")
  end

  def logout(conn, _params) do
    claims = get_session(conn, "oidc_claims")
    current_user_id = get_session(conn, "current_user_id")

    Logger.info(
      "User logout sub=#{claims && Map.get(claims, "sub")} email=#{claims && Map.get(claims, "email")} remote_ip=#{format_ip(conn.remote_ip)}"
    )

    AuditLog.record(:logout, current_user_id, format_ip(conn.remote_ip), %{
      email: claims && Map.get(claims, "email")
    })

    conn
    |> clear_session()
    |> redirect(to: ~p"/")
  end

  defp save_return_to(conn, _opts) do
    case conn.params["return_to"] do
      "/" <> _ = path -> put_session(conn, "return_to", path)
      _ -> conn
    end
  end

  defp format_ip(nil), do: nil
  defp format_ip(ip), do: ip |> Tuple.to_list() |> Enum.join(".")
end
