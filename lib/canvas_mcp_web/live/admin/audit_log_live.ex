defmodule CanvasMcpWeb.Admin.AuditLogLive do
  use CanvasMcpWeb, :live_view
  require Logger
  alias CanvasMcp.Data.AuditLog

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    if connected?(socket) do
      Phoenix.PubSub.subscribe(CanvasMcp.PubSub, AuditLog.topic())
    end

    entries =
      case AuditLog.list(limit: 200) do
        {:error, reason} ->
          Logger.error("AuditLogLive failed to load entries reason=#{inspect(reason)}")
          []

        rows ->
          rows
      end

    socket =
      socket
      |> assign(:current_user, current_user)
      |> stream(:entries, entries)

    {:ok, socket}
  end

  @impl true
  def handle_info({:new_audit_entry, entry}, socket) do
    {:noreply, stream_insert(socket, :entries, entry, at: 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-7xl px-4 py-8">
        <%!-- Page header --%>
        <div class="mb-6">
          <h1 class="text-2xl font-bold text-slate-50">Audit Log</h1>
          <p class="mt-1 text-sm text-slate-400">Real-time record of all user activity</p>
        </div>

        <div class="overflow-x-auto rounded-xl border border-slate-700 shadow-lg">
          <table class="min-w-full divide-y divide-slate-700 text-sm">
            <thead class="bg-slate-800">
              <tr>
                <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-slate-400">
                  Time
                </th>
                <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-slate-400">
                  Event
                </th>
                <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-slate-400">
                  User
                </th>
                <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-slate-400">
                  IP
                </th>
                <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-slate-400">
                  Data
                </th>
              </tr>
            </thead>
            <tbody
              id="audit-entries"
              phx-update="stream"
              class="divide-y divide-slate-700/60 bg-slate-900"
            >
              <tr
                :for={{id, entry} <- @streams.entries}
                id={id}
                class="hover:bg-slate-800/60 transition-colors"
              >
                <td class="px-4 py-3 whitespace-nowrap text-slate-500 font-mono text-xs">
                  {Calendar.strftime(entry.inserted_at, "%Y-%m-%d %H:%M:%S")}
                </td>
                <td class="px-4 py-3">
                  <span class={[
                    "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold",
                    entry.event == "login_success" &&
                      "bg-emerald-500/15 text-emerald-400 ring-1 ring-emerald-500/25",
                    entry.event == "login_failure" &&
                      "bg-red-500/15 text-red-400 ring-1 ring-red-500/25",
                    entry.event == "logout" && "bg-slate-700 text-slate-400",
                    entry.event == "session_refresh" &&
                      "bg-sky-500/15 text-sky-400 ring-1 ring-sky-500/25"
                  ]}>
                    {entry.event}
                  </span>
                </td>
                <td class="px-4 py-3 text-slate-300">{entry.user_email || "—"}</td>
                <td class="px-4 py-3 font-mono text-slate-500 text-xs">{entry.remote_ip || "—"}</td>
                <td class="px-4 py-3 text-slate-500 text-xs font-mono">
                  <%= if entry.data && map_size(entry.data) > 0 do %>
                    <details>
                      <summary class="cursor-pointer text-indigo-400 hover:text-indigo-300 transition-colors">
                        view
                      </summary>
                      <pre class="mt-2 rounded-lg bg-slate-800 p-2 text-xs text-slate-300 whitespace-pre-wrap border border-slate-700">{Jason.encode!(entry.data, pretty: true)}</pre>
                    </details>
                  <% else %>
                    <span class="text-slate-600">—</span>
                  <% end %>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
