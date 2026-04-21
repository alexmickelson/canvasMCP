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
        <h1 class="text-2xl font-bold text-gray-900 mb-6">Audit Log</h1>
        <div class="overflow-x-auto rounded-xl border border-gray-200 shadow-sm">
          <table class="min-w-full divide-y divide-gray-200 text-sm">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-3 text-left font-semibold text-gray-600">Time</th>
                <th class="px-4 py-3 text-left font-semibold text-gray-600">Event</th>
                <th class="px-4 py-3 text-left font-semibold text-gray-600">User</th>
                <th class="px-4 py-3 text-left font-semibold text-gray-600">IP</th>
                <th class="px-4 py-3 text-left font-semibold text-gray-600">Data</th>
              </tr>
            </thead>
            <tbody id="audit-entries" phx-update="stream" class="divide-y divide-gray-100 bg-white">
              <tr
                :for={{id, entry} <- @streams.entries}
                id={id}
                class="hover:bg-gray-50 transition-colors"
              >
                <td class="px-4 py-3 whitespace-nowrap text-gray-500 font-mono text-xs">
                  {Calendar.strftime(entry.inserted_at, "%Y-%m-%d %H:%M:%S")}
                </td>
                <td class="px-4 py-3">
                  <span class={[
                    "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
                    entry.event == "login_success" && "bg-green-100 text-green-800",
                    entry.event == "login_failure" && "bg-red-100 text-red-800",
                    entry.event == "logout" && "bg-gray-100 text-gray-700",
                    entry.event == "session_refresh" && "bg-blue-100 text-blue-700"
                  ]}>
                    {entry.event}
                  </span>
                </td>
                <td class="px-4 py-3 text-gray-700">{entry.user_email || "—"}</td>
                <td class="px-4 py-3 font-mono text-gray-500 text-xs">{entry.remote_ip || "—"}</td>
                <td class="px-4 py-3 text-gray-500 text-xs font-mono">
                  <%= if entry.data && map_size(entry.data) > 0 do %>
                    <details>
                      <summary class="cursor-pointer text-indigo-600 hover:underline">view</summary>
                      <pre class="mt-1 text-xs whitespace-pre-wrap">{Jason.encode!(entry.data, pretty: true)}</pre>
                    </details>
                  <% else %>
                    —
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
