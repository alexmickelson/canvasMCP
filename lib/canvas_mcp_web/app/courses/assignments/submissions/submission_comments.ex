defmodule CanvasMcpWeb.App.Courses.Submissions.SubmissionComments do
  use Phoenix.Component

  import CanvasMcpWeb.DateHelpers

  attr :comments, :list, required: true

  def submission_comments(assigns) do
    ~H"""
    <div class="space-y-3">
      <h4 class="text-xs font-semibold text-slate-400 uppercase tracking-wide">Comments</h4>
      <div class="space-y-2">
        <%= for comment <- @comments do %>
          <div class="rounded-lg bg-slate-900/60 border border-slate-700/40 p-3 space-y-1.5">
            <div class="flex items-center justify-between gap-2">
              <span class="text-xs font-medium text-slate-300">
                {get_in(comment, ["author", "display_name"]) || "Unknown"}
              </span>
              <span class="text-[10px] text-slate-500">
                {format_datetime(comment["created_at"])}
              </span>
            </div>
            <p class="text-xs text-slate-400 leading-relaxed">{comment["comment"]}</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
