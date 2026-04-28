defmodule CanvasMcpWeb.App.ServiceAccounts.ServiceAccountsLive do
  use CanvasMcpWeb, :live_view
  alias CanvasMcp.Data.ServiceAccount
  alias CanvasMcpWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    accounts =
      case ServiceAccount.list_for_user(user_id) do
        {:ok, list} -> list
        _ -> []
      end

    socket =
      socket
      |> assign(:name_form, to_form(%{"name" => ""}))
      |> assign(:new_token, nil)
      |> stream(:accounts, accounts)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("create", %{"name" => name}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply,
       assign(
         socket,
         :name_form,
         to_form(%{"name" => ""}, errors: [name: {"can't be blank", []}])
       )}
    else
      user_id = socket.assigns.current_user.id

      case ServiceAccount.create(user_id, name) do
        {:ok, account, raw_token} ->
          {:noreply,
           socket
           |> stream_insert(:accounts, account, at: 0)
           |> assign(:name_form, to_form(%{"name" => ""}))
           |> assign(:new_token, %{name: account["name"], token: raw_token})}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to create service account.")}
      end
    end
  end

  @impl true
  def handle_event("dismiss_token", _params, socket) do
    {:noreply, assign(socket, :new_token, nil)}
  end

  @impl true
  def handle_event("revoke", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id

    case ServiceAccount.revoke(id, user_id) do
      :ok ->
        {:noreply, stream_delete(socket, :accounts, %{"id" => id})}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to revoke service account.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} notifications={@notifications}>
      <div class="max-w-2xl mx-auto px-6 py-10 space-y-8">
        <div>
          <h1 class="text-xl font-bold text-slate-100">Service Accounts</h1>
          <p class="mt-1 text-sm text-slate-400">
            Generate tokens to authenticate against the API without using single sign-on.
            Tokens are only shown once at creation time.
          </p>
        </div>

        <%!-- New token banner --%>
        <%= if @new_token do %>
          <div
            id="new-token-banner"
            class="rounded-xl border border-emerald-500/40 bg-emerald-500/10 p-5 space-y-3"
          >
            <div class="flex items-start justify-between gap-4">
              <div>
                <p class="text-sm font-semibold text-emerald-400">
                  Token created — copy it now
                </p>
                <p class="text-xs text-slate-400 mt-0.5">
                  This token will not be shown again.
                </p>
              </div>
              <button
                phx-click="dismiss_token"
                class="text-slate-500 hover:text-slate-300 transition-colors text-lg leading-none"
              >
                &times;
              </button>
            </div>
            <div class="flex items-center gap-2">
              <code
                id="new-token-value"
                class="flex-1 block rounded-lg bg-slate-900 border border-slate-700 px-3 py-2 font-mono text-xs text-emerald-300 break-all select-all"
              >
                {@new_token.token}
              </code>
            </div>
          </div>
        <% end %>

        <%!-- Create form --%>
        <div class="rounded-xl border border-slate-700 bg-slate-800/60 p-5 space-y-4">
          <h2 class="text-sm font-semibold text-slate-200">Create new token</h2>
          <.form
            for={@name_form}
            id="create-service-account-form"
            phx-submit="create"
            class="flex gap-3 items-start"
          >
            <div class="flex-1">
              <input
                type="text"
                name="name"
                id="service-account-name"
                value={@name_form[:name].value}
                placeholder="e.g. My MCP client"
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
        </div>

        <%!-- Existing accounts --%>
        <div class="space-y-2">
          <h2 class="text-sm font-semibold text-slate-400 uppercase tracking-wide">Active tokens</h2>
          <div id="service-accounts" phx-update="stream" class="space-y-2">
            <div class="hidden only:block rounded-xl border border-slate-700 border-dashed px-6 py-8 text-center">
              <p class="text-sm text-slate-500">No service accounts yet.</p>
            </div>
            <div
              :for={{id, account} <- @streams.accounts}
              id={id}
              class="flex items-center justify-between gap-4 rounded-xl border border-slate-700 bg-slate-800/60 px-4 py-3"
            >
              <div class="min-w-0">
                <p class="text-sm font-medium text-slate-200 truncate">{account["name"]}</p>
                <p class="text-xs text-slate-500 mt-0.5 font-mono">
                  {account["token_prefix"]}••••••••
                  <span class="ml-2 font-sans not-italic">
                    &middot; created {format_date(account["inserted_at"])}
                  </span>
                </p>
              </div>
              <button
                phx-click="revoke"
                phx-value-id={account["id"]}
                data-confirm={"Revoke \"#{account["name"]}\"? Any clients using this token will lose access immediately."}
                class="shrink-0 rounded-lg border border-red-500/30 text-red-400 hover:bg-red-500/10 text-xs font-medium px-3 py-1.5 transition-colors"
              >
                Revoke
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_date(nil), do: ""

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %-d, %Y")
  end

  defp format_date(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> format_date(dt)
      _ -> str
    end
  end
end
