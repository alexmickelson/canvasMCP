defmodule CanvasMcpWeb.App.ServiceAccounts.ServiceAccountsPanel do
  use Phoenix.Component

  def format_date(nil), do: ""

  def format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %-d, %Y")
  end

  def format_date(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> format_date(dt)
      _ -> str
    end
  end

  attr :name_form, :map, required: true
  attr :new_token, :map, default: nil
  attr :accounts_stream, :list, required: true
  attr :revoke_confirm, :map, default: nil
  attr :form_key, :integer, default: 0

  def service_accounts_panel(assigns) do
    ~H"""
    <%!-- Revoke confirmation modal --%>
    <%= if @revoke_confirm do %>
      <div
        id="revoke-confirm-modal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm"
        phx-window-keydown="sa_revoke_cancel"
        phx-key="Escape"
      >
        <div class="relative bg-slate-900 border border-slate-700 rounded-2xl shadow-2xl w-full max-w-sm mx-4 p-6 space-y-5">
          <div class="space-y-1.5">
            <h3 class="text-base font-semibold text-slate-100">Revoke service account?</h3>
            <p class="text-sm text-slate-400">
              <span class="font-medium text-slate-200">"{@revoke_confirm["name"]}"</span>
              will be permanently revoked. Any clients using this token will lose access immediately.
            </p>
          </div>
          <div class="flex justify-end gap-3">
            <button
              phx-click="sa_revoke_cancel"
              class="rounded-lg border border-slate-600 text-slate-300 hover:bg-slate-800 text-sm font-medium px-4 py-2 transition-colors"
            >
              Cancel
            </button>
            <button
              phx-click="sa_revoke"
              phx-value-id={@revoke_confirm["id"]}
              class="rounded-lg bg-red-600 hover:bg-red-500 text-white text-sm font-medium px-4 py-2 transition-colors"
            >
              Revoke
            </button>
          </div>
        </div>
      </div>
    <% end %>

    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <h2 class="text-base font-semibold text-slate-200">Service Accounts</h2>
        <p class="text-xs text-slate-500">API tokens — shown only once at creation</p>
      </div>

      <%!-- New token banner --%>
      <%= if @new_token do %>
        <div
          id="new-token-banner"
          class="rounded-xl border border-emerald-500/40 bg-emerald-500/10 p-4 space-y-3"
        >
          <div class="flex items-start justify-between gap-4">
            <div>
              <p class="text-sm font-semibold text-emerald-400">Token created — copy it now</p>
              <p class="text-xs text-slate-400 mt-0.5">This token will not be shown again.</p>
            </div>
            <button
              phx-click="sa_dismiss_token"
              class="text-slate-500 hover:text-slate-300 transition-colors text-lg leading-none"
            >
              &times;
            </button>
          </div>
          <code
            id="new-token-value"
            class="block rounded-lg bg-slate-900 border border-slate-700 px-3 py-2 font-mono text-xs text-emerald-300 break-all select-all"
          >
            {@new_token.token}
          </code>
        </div>
      <% end %>

      <%!-- Create form — key changes on each successful create to reset the input --%>
      <.form
        for={@name_form}
        id={"create-service-account-form-#{@form_key}"}
        phx-submit="sa_create"
        class="flex gap-3 items-start"
      >
        <div class="flex-1">
          <input
            type="text"
            name="name"
            id={"service-account-name-#{@form_key}"}
            placeholder="Token name, e.g. My MCP client"
            autocomplete="off"
            class="w-full rounded-lg bg-slate-900 border border-slate-600 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 focus:outline-none focus:border-indigo-500 transition-colors"
          />
          <%= if @name_form[:name] && @name_form[:name].errors != [] do %>
            <p class="mt-1 text-xs text-red-400">Name can't be blank.</p>
          <% end %>
        </div>
        <button
          type="submit"
          class="rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-medium px-4 py-2 transition-colors shrink-0"
        >
          Generate
        </button>
      </.form>

      <%!-- Account list --%>
      <div id="service-accounts" phx-update="stream" class="space-y-2">
        <div class="hidden only:block rounded-xl border border-slate-700 border-dashed px-5 py-6 text-center">
          <p class="text-sm text-slate-500">No service accounts yet.</p>
        </div>
        <div
          :for={{id, account} <- @accounts_stream}
          id={id}
          class="flex items-center justify-between gap-4 rounded-xl border border-slate-700 bg-slate-800/60 px-4 py-3"
        >
          <div class="min-w-0">
            <.link
              navigate={"/app/service-accounts/#{account["id"]}"}
              class="text-sm font-medium text-slate-200 hover:text-indigo-400 transition-colors truncate block"
            >
              {account["name"]}
            </.link>
            <p class="text-xs text-slate-500 mt-0.5 font-mono">
              {account["token_prefix"]}••••••••
              <span class="ml-2 font-sans">
                &middot; created {format_date(account["inserted_at"])}
              </span>
            </p>
          </div>
          <button
            phx-click="sa_revoke_confirm"
            phx-value-id={account["id"]}
            phx-value-name={account["name"]}
            class="shrink-0 rounded-lg border border-red-500/30 text-red-400 hover:bg-red-500/10 text-xs font-medium px-3 py-1.5 transition-colors"
          >
            Revoke
          </button>
        </div>
      </div>
    </div>
    """
  end
end
