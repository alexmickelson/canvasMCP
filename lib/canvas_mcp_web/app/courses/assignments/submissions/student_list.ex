defmodule CanvasMcpWeb.App.Courses.Submissions.StudentList do
  use Phoenix.Component

  attr :submissions, :list, required: true
  attr :selected_id, :any, default: nil

  def student_list(assigns) do
    assigns = assign(assigns, :sorted, Enum.sort_by(assigns.submissions, &student_name/1))

    ~H"""
    <div class="divide-y divide-slate-700/40">
      <%= for sub <- @sorted do %>
        <button
          type="button"
          phx-click="select_submission"
          phx-value-id={sub.id}
          class={[
            "w-full text-left px-3 py-3 transition-colors border-l-2 group",
            sub.id == @selected_id && "bg-indigo-500/10 border-l-indigo-500",
            sub.id != @selected_id && "border-l-transparent hover:bg-slate-700/30"
          ]}
        >
          <div class="text-xs font-medium text-slate-200 truncate group-hover:text-slate-100 transition-colors">
            {student_name(sub)}
          </div>
          <div class="flex items-center gap-2 mt-1.5">
            <span class={[
              "inline-flex items-center rounded-full px-1.5 py-0.5 text-[10px] font-medium shrink-0",
              sub.workflow_state == "graded" && "bg-emerald-500/15 text-emerald-400",
              sub.workflow_state == "submitted" && "bg-indigo-500/15 text-indigo-400",
              sub.workflow_state == "pending_review" && "bg-amber-500/15 text-amber-400",
              sub.workflow_state not in ["graded", "submitted", "pending_review"] &&
                "bg-slate-700 text-slate-400"
            ]}>
              {state_label(sub.workflow_state)}
            </span>
            <span
              :if={sub.late}
              class="inline-flex items-center rounded-full px-1.5 py-0.5 text-[10px] font-medium bg-orange-500/15 text-orange-400 shrink-0"
            >
              Late
            </span>
            <span class="text-[10px] font-mono text-slate-500 ml-auto shrink-0">
              {format_score(sub.score, sub.grade)}
            </span>
          </div>
        </button>
      <% end %>
    </div>
    """
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
  defp format_score(score, _grade), do: "#{score}"
end
