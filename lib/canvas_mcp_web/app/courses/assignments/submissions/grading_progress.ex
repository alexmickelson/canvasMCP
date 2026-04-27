defmodule CanvasMcpWeb.App.Courses.Submissions.GradingProgress do
  use Phoenix.Component

  attr :stats, :map, required: true

  def grading_progress(assigns) do
    ~H"""
    <div class="rounded-xl border border-slate-700 bg-slate-800/60 px-5 py-4 space-y-3">
      <div class="flex items-center gap-3">
        <div class="flex-1 h-2 rounded-full bg-slate-700/60 overflow-hidden flex">
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
      <div class="flex flex-wrap gap-x-5 gap-y-1 text-xs text-slate-400">
        <span class="flex items-center gap-1.5">
          <span class="w-2 h-2 rounded-full bg-emerald-500 shrink-0"></span>
          Graded <span class="text-slate-200 font-semibold ml-1">{@stats.graded_pct_str}%</span>
        </span>
        <span :if={@stats.pending > 0} class="flex items-center gap-1.5">
          <span class="w-2 h-2 rounded-full bg-amber-500 shrink-0"></span>
          Pending review <span class="text-slate-300 font-medium ml-1">{@stats.pending}</span>
        </span>
        <span :if={@stats.submitted_only > 0} class="flex items-center gap-1.5">
          <span class="w-2 h-2 rounded-full bg-indigo-500 shrink-0"></span>
          Submitted, ungraded
          <span class="text-slate-300 font-medium ml-1">{@stats.submitted_only}</span>
        </span>
        <span :if={@stats.missing > 0} class="flex items-center gap-1.5">
          <span class="w-2 h-2 rounded-full bg-rose-500 shrink-0"></span>
          Missing <span class="text-rose-400 font-semibold ml-1">{@stats.missing_pct_str}%</span>
        </span>
      </div>
    </div>
    """
  end
end
