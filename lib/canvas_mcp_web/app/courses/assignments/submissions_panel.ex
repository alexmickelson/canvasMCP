defmodule CanvasMcpWeb.App.Courses.SubmissionsPanel do
  use Phoenix.Component

  import CanvasMcpWeb.App.Courses.Submissions.GradingProgress
  import CanvasMcpWeb.App.Courses.Submissions.StudentList
  import CanvasMcpWeb.App.Courses.Submissions.SubmissionDetail

  attr :submissions, :list, required: true
  attr :status, :atom, required: true
  attr :course_id, :integer, required: true
  attr :assignment_id, :integer, required: true
  attr :selected_submission_id, :any, default: nil
  attr :rubric, :any, default: nil

  def submissions_panel(assigns) do
    assigns =
      assigns
      |> assign(:stats, compute_stats(assigns.submissions))
      |> assign(:selected, find_selected(assigns.submissions, assigns.selected_submission_id))

    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between gap-3">
        <h2 class="text-sm font-semibold text-slate-300 tracking-wide uppercase">Submissions</h2>
        <button
          phx-click="refresh_submissions"
          disabled={@status == :refreshing}
          class={[
            "inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-medium transition-all",
            "border border-slate-700 bg-slate-800 text-slate-300",
            "hover:bg-slate-700 hover:text-slate-100 hover:border-slate-600",
            "disabled:opacity-50 disabled:cursor-not-allowed"
          ]}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class={["w-3.5 h-3.5", @status == :refreshing && "animate-spin"]}
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
          {if @status == :refreshing, do: "Refreshing…", else: "Refresh"}
        </button>
      </div>

      <%= cond do %>
        <% @status == nil or @status == :loading -> %>
          <div class="rounded-xl border border-slate-700/60 bg-slate-800/40 p-5 space-y-3">
            <div class="h-8 rounded-lg bg-slate-700/50 animate-pulse"></div>
            <div class="space-y-2 pt-2">
              <div :for={_ <- 1..5} class="h-9 rounded bg-slate-700/40 animate-pulse"></div>
            </div>
          </div>
        <% @status == :loaded or @status == :refreshing -> %>
          <.grading_progress stats={@stats} />

          <%= if @submissions == [] do %>
            <div class="rounded-xl border border-slate-700 border-dashed bg-slate-800/40 px-6 py-10 text-center">
              <p class="text-sm text-slate-500">
                No submissions yet. Press Refresh to fetch from Canvas.
              </p>
            </div>
          <% else %>
            <div class="flex gap-4 items-start">
              <div
                id="submissions-student-list"
                class={[
                  "rounded-xl border border-slate-700 bg-slate-900/60 overflow-hidden",
                  "transition-all duration-300 ease-in-out",
                  @selected && "w-64 shrink-0",
                  !@selected && "flex-1"
                ]}
              >
                <.student_list
                  submissions={@submissions}
                  selected_id={@selected && @selected.id}
                />
              </div>

              <div
                id="submissions-detail-panel"
                class={[
                  "overflow-hidden rounded-xl border bg-slate-800/40",
                  "transition-all duration-300 ease-in-out",
                  @selected && "flex-1 min-w-0 opacity-100 border-slate-700",
                  !@selected && "max-w-0 opacity-0 pointer-events-none border-transparent"
                ]}
              >
                <%= if @selected do %>
                  <.submission_detail submission={@selected} rubric={@rubric} />
                <% end %>
              </div>
            </div>
          <% end %>
        <% true -> %>
          <div></div>
      <% end %>
    </div>
    """
  end

  defp find_selected(_, nil), do: nil
  defp find_selected(submissions, id), do: Enum.find(submissions, &(&1.id == id))

  defp compute_stats([]) do
    %{
      total: 0,
      graded: 0,
      graded_pct: 0.0,
      graded_pct_str: "0",
      pending: 0,
      pending_pct: 0.0,
      submitted_only: 0,
      submitted_pct: 0.0,
      missing: 0,
      missing_pct: 0.0,
      missing_pct_str: "0"
    }
  end

  defp compute_stats(submissions) do
    total = length(submissions)
    graded = Enum.count(submissions, &(&1.workflow_state == "graded"))
    pending = Enum.count(submissions, &(&1.workflow_state == "pending_review"))
    submitted_only = Enum.count(submissions, &(&1.workflow_state == "submitted"))
    missing = Enum.count(submissions, &(&1.missing == true))

    pct = fn n -> if total > 0, do: Float.round(n / total * 100, 1), else: 0.0 end

    pct_str = fn n ->
      val = pct.(n)
      if val == trunc(val) * 1.0, do: "#{trunc(val)}", else: "#{val}"
    end

    %{
      total: total,
      graded: graded,
      graded_pct: pct.(graded),
      graded_pct_str: pct_str.(graded),
      pending: pending,
      pending_pct: pct.(pending),
      submitted_only: submitted_only,
      submitted_pct: pct.(submitted_only),
      missing: missing,
      missing_pct: pct.(missing),
      missing_pct_str: pct_str.(missing)
    }
  end
end
