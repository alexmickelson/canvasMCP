defmodule CanvasMcpWeb.App.Courses.CourseLive do
  use CanvasMcpWeb, :live_view
  alias CanvasMcp.UserActor
  alias CanvasMcp.Canvas.Course
  alias CanvasMcpWeb.Layouts

  @impl true
  def mount(%{"id" => id}, session, socket) do
    current_user = session["current_user"]
    {:ok, _pid} = UserActor.ensure_started(current_user.id)

    course_id = String.to_integer(id)

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

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="px-6 py-8 max-w-4xl mx-auto space-y-6">
        <div class="flex items-center gap-3">
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

        <div class="rounded-2xl border border-slate-700 border-dashed bg-slate-800/40 px-6 py-16 text-center">
          <p class="text-sm text-slate-500">Course details coming soon.</p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
