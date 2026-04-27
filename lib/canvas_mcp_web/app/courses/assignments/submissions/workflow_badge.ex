defmodule CanvasMcpWeb.App.Courses.Submissions.WorkflowBadge do
  use Phoenix.Component

  attr :state, :string, required: true
  attr :late, :any, default: false
  attr :missing, :any, default: false
  attr :excused, :any, default: false

  def workflow_badge(assigns) do
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

  defp state_label("graded"), do: "Graded"
  defp state_label("submitted"), do: "Submitted"
  defp state_label("pending_review"), do: "Pending Review"
  defp state_label("unsubmitted"), do: "Not Submitted"
  defp state_label(other), do: other
end
