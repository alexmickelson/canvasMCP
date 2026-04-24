defmodule CanvasMcpWeb.App.Courses.SubmissionsPanel do
  use Phoenix.Component
  import CanvasMcpWeb.DateHelpers

  attr :submissions, :list, required: true
  attr :status, :atom, required: true
  attr :course_id, :integer, required: true
  attr :assignment_id, :integer, required: true

  def submissions_panel(assigns) do
    assigns =
      assigns
      |> assign(:stats, compute_stats(assigns.submissions))

    ~H"""
    <div class="space-y-4">
      <%!-- Header row --%>
      <div class="flex items-center justify-between gap-3">
        <h2 class="text-sm font-semibold text-slate-300 tracking-wide uppercase">
          Submissions
        </h2>
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
          <%!-- Skeleton --%>
          <div class="rounded-xl border border-slate-700/60 bg-slate-800/40 p-5 space-y-3">
            <div class="h-8 rounded-lg bg-slate-700/50 animate-pulse"></div>
            <div class="space-y-2 pt-2">
              <div :for={_ <- 1..5} class="h-9 rounded bg-slate-700/40 animate-pulse"></div>
            </div>
          </div>
        <% @status == :loaded or @status == :refreshing -> %>
          <%!-- Grading progress bar --%>
          <.grading_progress stats={@stats} />

          <%!-- Table --%>
          <%= if @submissions == [] do %>
            <div class="rounded-xl border border-slate-700 border-dashed bg-slate-800/40 px-6 py-10 text-center">
              <p class="text-sm text-slate-500">
                No submissions yet. Press Refresh to fetch from Canvas.
              </p>
            </div>
          <% else %>
            <div class="rounded-xl border border-slate-700 bg-slate-800/60 overflow-hidden">
              <table class="w-full text-sm">
                <thead>
                  <tr class="border-b border-slate-700 bg-slate-900/60">
                    <th class="text-left px-4 py-2.5 text-xs font-semibold text-slate-500 uppercase tracking-wide">
                      Student
                    </th>
                    <th class="text-left px-4 py-2.5 text-xs font-semibold text-slate-500 uppercase tracking-wide">
                      Status
                    </th>
                    <th class="text-left px-4 py-2.5 text-xs font-semibold text-slate-500 uppercase tracking-wide">
                      Submitted
                    </th>
                    <th class="text-right px-4 py-2.5 text-xs font-semibold text-slate-500 uppercase tracking-wide">
                      Score
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <%= for submission <- Enum.sort_by(@submissions, &student_name/1) do %>
                    <tr class="border-b border-slate-700/50 last:border-0 hover:bg-slate-700/20 transition-colors">
                      <td class="px-4 py-3 text-slate-200 font-medium">
                        {student_name(submission)}
                      </td>
                      <td class="px-4 py-3">
                        <.workflow_badge
                          state={submission.workflow_state}
                          late={submission.late}
                          missing={submission.missing}
                          excused={submission.excused}
                        />
                      </td>
                      <td class="px-4 py-3 text-slate-400 text-xs">
                        {format_date(submission.submitted_at)}
                      </td>
                      <td class="px-4 py-3 text-right font-mono text-slate-300 text-xs">
                        {format_score(submission.score, submission.grade)}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        <% true -> %>
          <div></div>
      <% end %>
    </div>
    """
  end

  attr :stats, :map, required: true

  defp grading_progress(assigns) do
    ~H"""
    <div class="rounded-xl border border-slate-700 bg-slate-800/60 px-5 py-4 space-y-3">
      <%!-- Bar + count label --%>
      <div class="flex items-center gap-3">
        <div class="flex-1 h-2.5 rounded-full bg-slate-700 overflow-hidden flex">
          <div
            :if={@stats.graded_pct > 0}
            class="h-full bg-emerald-500 transition-all duration-500"
            style={"width: #{@stats.graded_pct}%"}
          />
          <div
            :if={@stats.pending_pct > 0}
            class="h-full bg-amber-500 transition-all duration-500"
            style={"width: #{@stats.pending_pct}%"}
          />
          <div
            :if={@stats.submitted_pct > 0}
            class="h-full bg-indigo-500 transition-all duration-500"
            style={"width: #{@stats.submitted_pct}%"}
          />
          <div
            :if={@stats.missing_pct > 0}
            class="h-full bg-rose-500/70 transition-all duration-500"
            style={"width: #{@stats.missing_pct}%"}
          />
        </div>
        <span class="text-xs font-mono text-slate-400 shrink-0">
          {@stats.graded}/{@stats.total} graded
        </span>
      </div>
      <%!-- Legend --%>
      <div class="flex flex-wrap gap-x-5 gap-y-1.5 text-xs text-slate-400">
        <span class="flex items-center gap-1.5">
          <span class="w-2 h-2 rounded-full bg-emerald-500 shrink-0"></span>
          Graded <span class="text-slate-200 font-semibold">{@stats.graded_pct_str}%</span>
        </span>
        <span :if={@stats.pending > 0} class="flex items-center gap-1.5">
          <span class="w-2 h-2 rounded-full bg-amber-500 shrink-0"></span>
          Pending review <span class="text-slate-300 font-medium">{@stats.pending}</span>
        </span>
        <span :if={@stats.submitted_only > 0} class="flex items-center gap-1.5">
          <span class="w-2 h-2 rounded-full bg-indigo-500 shrink-0"></span>
          Submitted, ungraded <span class="text-slate-300 font-medium">{@stats.submitted_only}</span>
        </span>
        <span :if={@stats.missing > 0} class="flex items-center gap-1.5">
          <span class="w-2 h-2 rounded-full bg-rose-500 shrink-0"></span>
          Missing <span class="text-rose-400 font-semibold">{@stats.missing_pct_str}%</span>
        </span>
      </div>
    </div>
    """
  end

  attr :state, :string, required: true
  attr :late, :any, default: false
  attr :missing, :any, default: false
  attr :excused, :any, default: false

  defp workflow_badge(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-1">
      <span class={[
        "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
        @state == "graded" && "bg-emerald-500/15 text-emerald-400",
        @state == "submitted" && "bg-indigo-500/15 text-indigo-400",
        @state == "pending_review" && "bg-amber-500/15 text-amber-400",
        @state not in ["graded", "submitted", "pending_review"] && "bg-slate-700 text-slate-400"
      ]}>
        {state_label(@state)}
      </span>
      <span
        :if={@late}
        class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium bg-orange-500/15 text-orange-400"
      >
        Late
      </span>
      <span
        :if={@missing}
        class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium bg-rose-500/15 text-rose-400"
      >
        Missing
      </span>
      <span
        :if={@excused}
        class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium bg-slate-600 text-slate-300"
      >
        Excused
      </span>
    </div>
    """
  end

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

  defp student_name(%{user: %{name: name}}) when is_binary(name), do: name
  defp student_name(_), do: "Unknown"

  defp state_label("graded"), do: "Graded"
  defp state_label("submitted"), do: "Submitted"
  defp state_label("pending_review"), do: "Pending Review"
  defp state_label("unsubmitted"), do: "Not Submitted"
  defp state_label(other), do: other

  defp format_score(nil, nil), do: "—"
  defp format_score(nil, grade), do: grade
  defp format_score(score, nil), do: Float.to_string(score / 1)
  defp format_score(score, _grade), do: "#{score}"

  defp format_date(nil), do: "—"

  defp format_date(datetime_str) do
    case DateTime.from_iso8601(datetime_str) do
      {:ok, dt, _} ->
        month = dt.month |> month_abbr()
        "#{month} #{dt.day}, #{dt.year}"

      _ ->
        datetime_str
    end
  end

  defp month_abbr(1), do: "Jan"
  defp month_abbr(2), do: "Feb"
  defp month_abbr(3), do: "Mar"
  defp month_abbr(4), do: "Apr"
  defp month_abbr(5), do: "May"
  defp month_abbr(6), do: "Jun"
  defp month_abbr(7), do: "Jul"
  defp month_abbr(8), do: "Aug"
  defp month_abbr(9), do: "Sep"
  defp month_abbr(10), do: "Oct"
  defp month_abbr(11), do: "Nov"
  defp month_abbr(12), do: "Dec"
end
