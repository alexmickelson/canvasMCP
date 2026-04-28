defmodule CanvasMcpWeb.App.ServiceAccounts.ServiceAccountLive do
  use CanvasMcpWeb, :live_view
  require Logger
  alias CanvasMcp.Data.ServiceAccount

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    current_user = socket.assigns.current_user

    case ServiceAccount.get_by_id(id, current_user.id) do
      {:error, :not_found} ->
        {:ok, push_navigate(socket, to: "/app")}

      {:error, reason} ->
        Logger.error("ServiceAccountLive mount error: #{inspect(reason)}")
        {:ok, push_navigate(socket, to: "/app")}

      {:ok, account} ->
        courses = load_courses(id, current_user)

        socket =
          socket
          |> assign(:service_account, account)
          |> assign(:courses, courses)

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("assign_course", %{"course_id" => course_id}, socket) do
    sa_id = socket.assigns.service_account["id"]
    user_id = socket.assigns.current_user.id

    case ServiceAccount.assign_course(sa_id, course_id, user_id) do
      :ok ->
        {:noreply, update(socket, :courses, &toggle_assigned(&1, course_id, true))}

      {:error, reason} ->
        Logger.error("assign_course failed: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("unassign_course", %{"course_id" => course_id}, socket) do
    sa_id = socket.assigns.service_account["id"]
    user_id = socket.assigns.current_user.id

    case ServiceAccount.unassign_course(sa_id, course_id, user_id) do
      :ok ->
        {:noreply, update(socket, :courses, &toggle_assigned(&1, course_id, false))}

      {:error, reason} ->
        Logger.error("unassign_course failed: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  defp load_courses(service_account_id, current_user) do
    case current_user.canvas_user_id do
      nil ->
        []

      canvas_user_id ->
        case ServiceAccount.list_courses_with_assignment(service_account_id, canvas_user_id) do
          {:ok, rows} -> rows
          _ -> []
        end
    end
  end

  defp toggle_assigned(courses, course_id, assigned) do
    Enum.map(courses, fn course ->
      if to_string(course["id"]) == to_string(course_id) do
        Map.put(course, "assigned", assigned)
      else
        course
      end
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} notifications={@notifications}>
      <div class="px-6 py-8 max-w-3xl space-y-8">
        <%!-- Header --%>
        <div>
          <.link
            navigate="/app"
            class="inline-flex items-center gap-1.5 text-xs text-slate-500 hover:text-slate-300 transition-colors mb-4"
          >
            <svg
              class="w-3.5 h-3.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" />
            </svg>
            Back to home
          </.link>

          <h1 class="text-xl font-semibold text-slate-100">{@service_account["name"]}</h1>
          <p class="text-sm text-slate-500 mt-1 font-mono">
            {@service_account["token_prefix"]}••••••••
          </p>
        </div>

        <%!-- Course assignment --%>
        <div class="space-y-4">
          <div>
            <h2 class="text-sm font-semibold text-slate-200">Course Access</h2>
            <p class="text-xs text-slate-500 mt-0.5">
              Toggle which of your courses this service account can see. Unassigned courses are hidden from MCP queries.
            </p>
          </div>

          <%= if @courses == [] do %>
            <div class="rounded-xl border border-slate-700 border-dashed px-5 py-8 text-center">
              <p class="text-sm text-slate-500">No courses found. Sync your Canvas courses from the home page first.</p>
            </div>
          <% else %>
            <%!-- Group by term --%>
            <%= for {term, term_courses} <- group_by_term(@courses) do %>
              <div class="space-y-2">
                <p class="text-xs font-semibold text-slate-400 uppercase tracking-wider px-1">
                  {term}
                </p>
                <%= for course <- term_courses do %>
                  <div class="flex items-center justify-between gap-4 rounded-xl border border-slate-700 bg-slate-800/60 px-4 py-3">
                    <div class="min-w-0">
                      <p class="text-sm font-medium text-slate-200 truncate">{course["name"]}</p>
                      <p class="text-xs text-slate-500 mt-0.5">{course["course_code"]}</p>
                    </div>
                    <%= if course["assigned"] do %>
                      <button
                        phx-click="unassign_course"
                        phx-value-course_id={course["id"]}
                        class="shrink-0 flex items-center gap-1.5 rounded-lg bg-indigo-500/20 border border-indigo-500/40 text-indigo-400 hover:bg-red-500/10 hover:border-red-500/30 hover:text-red-400 text-xs font-medium px-3 py-1.5 transition-all"
                      >
                        <svg
                          class="w-3.5 h-3.5"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                          stroke-width="2.5"
                        >
                          <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                        </svg>
                        Assigned
                      </button>
                    <% else %>
                      <button
                        phx-click="assign_course"
                        phx-value-course_id={course["id"]}
                        class="shrink-0 rounded-lg border border-slate-600 text-slate-400 hover:bg-indigo-500/10 hover:border-indigo-500/40 hover:text-indigo-400 text-xs font-medium px-3 py-1.5 transition-all"
                      >
                        Assign
                      </button>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp group_by_term(courses) do
    courses
    |> Enum.group_by(&(&1["term_name"] || "No Term"))
    |> Enum.sort_by(fn {term, _} -> term end, :desc)
  end
end
