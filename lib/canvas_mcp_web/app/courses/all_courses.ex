defmodule CanvasMcpWeb.App.Courses do
  use Phoenix.Component
  import CanvasMcpWeb.Components.Icon
  import CanvasMcpWeb.App.Courses.TermSelector

  attr :courses, :list, required: true
  attr :status, :atom, default: nil
  attr :selected_term, :string, default: nil

  def all_courses(assigns) do
    grouped = group_by_semester(assigns.courses)
    terms = Enum.map(grouped, fn {name, _} -> name end)
    active = assigns.selected_term || List.first(terms)

    filtered =
      case Enum.find(grouped, fn {name, _} -> name == active end) do
        {_, courses} -> courses
        nil -> []
      end

    assigns =
      assigns
      |> assign(:terms, terms)
      |> assign(:active_term, active)
      |> assign(:filtered_courses, filtered)

    ~H"""
    <div class="space-y-5">
      <div class="flex items-start justify-between gap-4">
        <div>
          <h2 class="text-xl font-bold text-slate-100">Courses</h2>
          <p class="text-xs text-slate-500 mt-1">
            <%= if @active_term do %>
              {@active_term} &middot; {length(@filtered_courses)} course{if length(@filtered_courses) !=
                                                                              1,
                                                                            do: "s"}
            <% else %>
              {length(@courses)} course{if length(@courses) != 1, do: "s"}
            <% end %>
          </p>
        </div>
        <div class="flex items-center gap-3 shrink-0">
          <%= if @status == :refreshed do %>
            <span class="flex items-center gap-1 text-xs text-emerald-400">
              <.icon name="hero-check" class="w-3.5 h-3.5" /> Updated
            </span>
          <% end %>
          <%= if @status == :refreshing do %>
            <span class="flex items-center gap-1 text-xs text-slate-400">
              <.icon name="hero-arrow-path" class="w-3.5 h-3.5 animate-spin" /> Loading…
            </span>
          <% end %>
          <button
            type="button"
            phx-click="refresh_courses"
            disabled={@status == :refreshing}
            class="inline-flex items-center gap-1.5 rounded-lg border border-slate-600 px-3 py-1.5 text-xs font-semibold text-slate-300 hover:bg-slate-700 hover:border-slate-500 active:scale-95 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <.icon name="hero-arrow-path" class="w-3.5 h-3.5" /> Refresh
          </button>
        </div>
      </div>

      <.term_selector terms={@terms} active_term={@active_term} />

      <%= if @courses == [] do %>
        <div class="rounded-2xl border border-slate-700 border-dashed bg-slate-800/40 px-6 py-14 text-center">
          <.icon name="hero-academic-cap" class="w-8 h-8 text-slate-600 mx-auto mb-3" />
          <p class="text-sm text-slate-500">No courses cached yet.</p>
          <p class="text-xs text-slate-600 mt-1">Click Refresh to load from Canvas.</p>
        </div>
      <% else %>
        <%= if @filtered_courses == [] do %>
          <div class="rounded-2xl border border-slate-700 border-dashed bg-slate-800/40 px-6 py-12 text-center">
            <p class="text-sm text-slate-500">No courses found for this term.</p>
          </div>
        <% else %>
          <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
            <%= for course <- @filtered_courses do %>
              <.link
                navigate={"/app/courses/#{course.id}"}
                class="group relative rounded-xl border border-slate-700 bg-slate-800 p-5 flex flex-col gap-4 hover:border-slate-600 hover:bg-slate-700/40 transition-all duration-150 shadow-sm hover:shadow-lg hover:shadow-black/20"
              >
                <div class="flex items-start justify-between gap-3">
                  <p class="text-sm font-semibold text-slate-100 leading-snug">{course.name}</p>
                  <span class={[
                    "shrink-0 inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
                    course.workflow_state == "available" &&
                      "bg-emerald-500/15 text-emerald-400",
                    course.workflow_state != "available" && "bg-slate-700 text-slate-400"
                  ]}>
                    {course.workflow_state}
                  </span>
                </div>
                <p class="text-xs font-mono text-slate-500 mt-auto">{course.course_code}</p>
              </.link>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
