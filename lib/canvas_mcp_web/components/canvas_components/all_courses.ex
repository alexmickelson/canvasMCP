defmodule CanvasMcpWeb.CanvasComponents.AllCourses do
  use Phoenix.Component
  import CanvasMcpWeb.CoreComponents

  attr :courses, :list, required: true

  def all_courses(assigns) do
    ~H"""
    <div class="rounded-2xl border border-slate-700 bg-slate-800 shadow-lg mb-5">
      <div class="px-6 py-4 border-b border-slate-700 flex items-center justify-between">
        <div>
          <h2 class="text-sm font-semibold uppercase tracking-wider text-slate-400">Courses</h2>
          <p class="mt-0.5 text-xs text-slate-500">
            {length(@courses)} course{if length(@courses) != 1, do: "s"}
          </p>
        </div>
        <button
          type="button"
          phx-click="refresh_courses"
          class="inline-flex items-center gap-1.5 rounded-lg border border-slate-600 px-3 py-1.5 text-xs font-semibold text-slate-300 hover:bg-slate-700 hover:border-slate-500 active:scale-95 transition-all"
        >
          <.icon name="hero-arrow-path" class="w-3.5 h-3.5" /> Refresh from Canvas
        </button>
      </div>
      <%= if @courses == [] do %>
        <div class="px-6 py-10 text-center">
          <p class="text-sm text-slate-500">
            No courses cached yet. Click Refresh to load from Canvas.
          </p>
        </div>
      <% else %>
        <div class="divide-y divide-slate-700/60">
          <%= for course <- @courses do %>
            <div class="px-6 py-4 flex items-start justify-between gap-4">
              <div class="min-w-0">
                <p class="text-sm font-medium text-slate-100 truncate">{course.name}</p>
                <p class="text-xs text-slate-400 mt-0.5">{course.course_code}</p>
              </div>
              <div class="flex items-center gap-3 shrink-0">
                <%= if course[:term] do %>
                  <span class="text-xs text-slate-400 font-mono">{course.term.name}</span>
                <% end %>
                <span class={[
                  "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
                  course.workflow_state == "available" && "bg-emerald-500/15 text-emerald-400",
                  course.workflow_state != "available" && "bg-slate-700 text-slate-400"
                ]}>
                  {course.workflow_state}
                </span>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
