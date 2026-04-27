defmodule CanvasMcpWeb.App.Courses.AssignmentInCalendarDay do
  use Phoenix.Component

  attr :assignment, :map, required: true
  attr :course_id, :integer, required: true
  attr :submissions, :list, default: []
  attr :active_student_ids, :any, default: nil

  def assignment_in_calendar_day(assigns) do
    active_submissions =
      case assigns.active_student_ids do
        nil -> assigns.submissions
        ids -> Enum.filter(assigns.submissions, &MapSet.member?(ids, &1.user_id))
      end

    assigns = assign(assigns, :bar, submission_bar(active_submissions))

    ~H"""
    <div class="relative pill-wrapper">
      <.link
        navigate={"/app/courses/#{@course_id}/assignments/#{@assignment.id}"}
        class={[
          "rounded overflow-hidden flex flex-col hover:opacity-80 transition-opacity",
          @assignment.published &&
            "bg-indigo-500/20 text-indigo-300 border border-indigo-500/30",
          !@assignment.published &&
            "bg-slate-700/60 text-slate-400 border border-slate-600/40"
        ]}
      >
        <span class="px-1.5 pt-0.5 pb-0.5 leading-tight truncate">
          {@assignment.name}
        </span>
        <%!-- Progress bar: graded (emerald) | submitted-ungraded (sky) | not submitted (track) --%>
        <div class="h-1 w-full flex">
          <%!-- Graded segment — emerald-400, highest lightness --%>
          <div
            :if={@bar.graded_pct > 0}
            class="h-full bg-emerald-800"
            style={"width: #{@bar.graded_pct}%"}
          />
          <%!-- Submitted-but-ungraded segment — sky-500, medium lightness --%>
          <div
            :if={@bar.ungraded_pct > 0}
            class="h-full bg-sky-800"
            style={"width: #{@bar.ungraded_pct}%"}
          />
          <%!-- Remainder — slate-600/50, lowest lightness --%>
          <div class="h-full bg-slate-600/50 flex-1" />
        </div>
      </.link>

      <%!-- Hover tooltip --%>
      <%= if @bar.total > 0 do %>
        <div class="pill-tooltip pointer-events-none absolute bottom-full left-0 mb-1.5 z-50">
          <div class="rounded-lg bg-slate-900 border border-slate-700 shadow-xl px-3 py-2 space-y-1.5 min-w-[140px]">
            <p class=" font-semibold text-slate-200 truncate">{@assignment.name}</p>
            <div class="space-y-1">
              <div class="flex items-center gap-2">
                <span class="w-2 h-2 rounded-sm bg-emerald-300 shrink-0"></span>
                <span class="w-10 text-end font-mono font-semibold text-emerald-200">
                  {@bar.graded_pct}%
                </span>
                <span class=" text-slate-400">Graded</span>
              </div>
              <div class="flex items-center gap-2">
                <span class="w-2 h-2 rounded-sm bg-sky-300 shrink-0"></span>
                <span class="w-10 text-end font-mono font-semibold text-sky-200 ">
                  {@bar.ungraded_pct}%
                </span>
                <span class=" text-slate-400">Submitted</span>
              </div>
            </div>
            <p class=" text-slate-600 pt-0.5 border-t border-slate-800">
              {@bar.total} total
            </p>
          </div>
          <%!-- Arrow --%>
          <div class="w-2 h-2 bg-slate-900 border-r border-b border-slate-700 rotate-45 ml-3 -mt-1">
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp submission_bar([]) do
    %{total: 0, graded_pct: 0, ungraded_pct: 0}
  end

  defp submission_bar(submissions) do
    total = length(submissions)
    graded = Enum.count(submissions, &(&1.workflow_state == "graded"))
    submitted = Enum.count(submissions, &(&1.workflow_state in ["submitted", "pending_review"]))
    ungraded = submitted

    graded_pct = round(graded / total * 100)
    ungraded_pct = round(ungraded / total * 100)

    %{total: total, graded_pct: graded_pct, ungraded_pct: ungraded_pct}
  end
end
