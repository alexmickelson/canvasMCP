defmodule CanvasMcp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CanvasMcp.Repo,
      %{id: CanvasMcp.UserPG, start: {:pg, :start_link, [CanvasMcp.UserPG]}},
      {Registry, keys: :unique, name: CanvasMcp.UserRegistry},
      {DynamicSupervisor, name: CanvasMcp.UserServerSupervisor, strategy: :one_for_one},
      {Oidcc.ProviderConfiguration.Worker,
       %{
         issuer: Application.fetch_env!(:canvas_mcp, :oidc) |> Keyword.fetch!(:issuer),
         name: CanvasMcp.OidcProvider,
         provider_configuration_opts: %{
           quirks: %{
             document_overrides: %{
               # Disable PAR - oidcc attempts PAR whenever the endpoint is present,
               # which fails for public (PKCE) clients against Keycloak's token endpoint.
               "pushed_authorization_request_endpoint" => :undefined,
               "require_pushed_authorization_requests" => false,
               # Keycloak doesn't advertise "none" in token_endpoint_auth_methods_supported,
               # but public clients (PKCE, no secret) require it to authenticate with just client_id.
               "token_endpoint_auth_methods_supported" => [
                 "private_key_jwt",
                 "client_secret_basic",
                 "client_secret_post",
                 "tls_client_auth",
                 "client_secret_jwt",
                 "none"
               ]
             }
           }
         }
       }},
      CanvasMcpWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:canvas_mcp, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CanvasMcp.PubSub},
      CanvasMcpWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: CanvasMcp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    CanvasMcpWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
