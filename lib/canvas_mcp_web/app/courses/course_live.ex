defmodule CanvasMcpWeb.App.Courses.CourseLive do
  use CanvasMcpWeb, :live_view
  alias CanvasMcp.UserActor
  alias CanvasMcp.Canvas.Course
  alias CanvasMcpWeb.Layouts
  import CanvasMcpWeb.App.Courses.CourseCalendar

  @impl true
  def mount(%{"course_id" => id}, session, socket) do
    current_user = session["current_user"]
    {:ok, _pid} = UserActor.ensure_started(current_user.id)

    course_id = String.to_integer(id)

    if connected?(socket) do
      UserActor.subscribe_to_user(current_user.id)
      UserActor.get_course_assignments(current_user.id, course_id)
    end

    course =
      case Course.get_by_id(course_id) do
        {:ok, c} -> c
        _ -> nil
      end

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:course_id, course_id)
      |> assign(:course, course)
      |> assign(:assignments_status, nil)
      |> assign(:assignments_list, [])
      |> assign(:submissions_map, %{})
      |> stream(:assignments, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:canvas, :assignments_loaded, {course_id, assignments}}, socket) do
    if course_id == socket.assigns.course_id do
      {:noreply,
       socket
       |> assign(:assignments_status, :loaded)
       |> assign(:assignments_list, assignments)
       |> stream(:assignments, assignments, reset: true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("refresh_assignments", _params, socket) do
    UserActor.refresh_assignments_with_submissions(
      socket.assigns.current_user.id,
      socket.assigns.course_id
    )

    {:noreply, assign(socket, :assignments_status, :refreshing)}
  end

  @impl true
  def handle_info({:canvas, :submissions_loaded, {assignment_id, submissions}}, socket) do
    {:noreply, update(socket, :submissions_map, &Map.put(&1, assignment_id, submissions))}
  end

  @impl true
  def handle_info({:canvas, _event, _data}, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="px-6 py-8 max-w-7xl mx-auto space-y-6">
        <div class="flex items-center justify-between gap-4">
          <div class="flex items-center gap-3 min-w-0">
            <.link
              navigate="/app"
              class="inline-flex items-center gap-1 text-xs text-slate-600 hover:text-slate-400 transition-colors shrink-0"
            >
              <svg
                class="w-3 h-3"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" />
              </svg>
              Courses
            </.link>
            <%= if @course do %>
              <span class="text-slate-700 text-xs">/</span>
              <h1 class="text-sm font-semibold text-slate-200 truncate">{@course.name}</h1>
              <span class="text-slate-700 text-xs">&middot;</span>
              <span class="text-xs text-slate-500 shrink-0">
                {get_in(@course, [:term, :name]) || "No term"}
              </span>
            <% else %>
              <span class="text-slate-700 text-xs">/</span>
              <div class="h-4 w-48 rounded bg-slate-800 animate-pulse"></div>
            <% end %>
          </div>
          <div class="flex items-center gap-3 shrink-0">
            <%= if @assignments_status == :loaded do %>
              <span class="text-xs text-emerald-400">Updated</span>
            <% end %>
            <button
              type="button"
              phx-click="refresh_assignments"
              disabled={@assignments_status == :refreshing}
              class="inline-flex items-center gap-1.5 rounded-lg border border-slate-600 px-3 py-1.5 text-xs font-semibold text-slate-300 hover:bg-slate-700 hover:border-slate-500 active:scale-95 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg
                class={["w-3.5 h-3.5", @assignments_status == :refreshing && "animate-spin"]}
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                />
              </svg>
              {if @assignments_status == :refreshing, do: "Loading…", else: "Refresh"}
            </button>
          </div>
        </div>

        <.course_calendar
          assignments={@assignments_list}
          course_id={@course_id}
          submissions_map={@submissions_map}
        />
      </div>
    </Layouts.app>
    """
  end
end
