import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :canvas_mcp, CanvasMcpWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "UfQjbe79iGRQ+TuT3iQs0snhxVKIsBhvDES48ayejgYM7wCkOVPfJV35XlNvB9LQ",
  server: false

# In test we don't send emails
config :canvas_mcp, CanvasMcp.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
