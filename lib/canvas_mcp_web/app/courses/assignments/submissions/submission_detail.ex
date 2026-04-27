defmodule CanvasMcpWeb.App.Courses.Submissions.SubmissionDetail do
  use Phoenix.Component

  import CanvasMcpWeb.DateHelpers
  import CanvasMcpWeb.App.Courses.Submissions.WorkflowBadge
  import CanvasMcpWeb.App.Courses.Submissions.RubricAssessment
  import CanvasMcpWeb.App.Courses.Submissions.SubmissionComments

  attr :submission, :any, required: true
  attr :rubric, :any, default: nil

  def submission_detail(assigns) do
    assigns =
      assigns
      |> assign(:comments, Map.get(assigns.submission, :submission_comments) || [])
      |> assign(:rubric_assessment, Map.get(assigns.submission, :rubric_assessment))
      |> assign(:body, Map.get(assigns.submission, :body))
      |> assign(:html_url, Map.get(assigns.submission, :html_url))
      |> assign(:attachments, Map.get(assigns.submission, :attachments) || [])

    ~H"""
    <div class="p-5 space-y-5">
      <div class="flex items-start justify-between gap-4">
        <div class="min-w-0">
          <h3 class="text-base font-semibold text-slate-100 truncate">
            {student_name(@submission)}
          </h3>
          <div class="mt-2">
            <.workflow_badge
              state={@submission.workflow_state}
              late={@submission.late}
              missing={@submission.missing}
              excused={@submission.excused}
            />
          </div>
        </div>
        <div class="text-right shrink-0">
          <div class="text-2xl font-bold font-mono text-slate-100">
            {format_score(@submission.score, @submission.grade)}
          </div>
          <div class="text-[10px] text-slate-500 uppercase tracking-wide mt-0.5">score</div>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-2">
        <.detail_field label="Submitted" value={format_datetime(@submission.submitted_at)} />
        <.detail_field label="Graded" value={format_datetime(@submission.graded_at)} />
        <.detail_field label="Type" value={format_submission_type(@submission.submission_type)} />
        <.detail_field
          label="Attempt"
          value={if @submission.attempt, do: "##{@submission.attempt}", else: "—"}
        />
      </div>

      <%= if @rubric do %>
        <.rubric_assessment rubric={@rubric} assessment={@rubric_assessment || %{}} />
      <% end %>

      <%!-- Submitted content --%>
      <%= if @body do %>
        <div class="space-y-2">
          <h4 class="text-xs font-semibold text-slate-400 uppercase tracking-wide">
            Submitted Text
          </h4>
          <div class="rounded-lg bg-slate-900/60 border border-slate-700/40 p-3 text-xs text-slate-300 leading-relaxed overflow-x-auto submission-body">
            {Phoenix.HTML.raw(@body)}
          </div>
        </div>
      <% end %>

      <%= if @attachments != [] do %>
        <div class="space-y-2">
          <h4 class="text-xs font-semibold text-slate-400 uppercase tracking-wide">
            Attachments
          </h4>
          <div class="space-y-1.5">
            <%= for file <- @attachments do %>
              <a
                href={file["url"]}
                target="_blank"
                rel="noopener noreferrer"
                class="flex items-center gap-2.5 rounded-lg bg-slate-900/60 border border-slate-700/40 px-3 py-2 hover:bg-slate-800 hover:border-slate-600 transition-colors group"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="w-4 h-4 text-slate-500 group-hover:text-slate-400 shrink-0"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="1.5"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"
                  />
                </svg>
                <span class="text-xs text-slate-300 group-hover:text-slate-100 truncate transition-colors">
                  {file["display_name"] || file["filename"] || "File"}
                </span>
                <%= if file["size"] do %>
                  <span class="text-[10px] text-slate-500 ml-auto shrink-0">
                    {format_file_size(file["size"])}
                  </span>
                <% end %>
              </a>
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if @html_url && @body == nil && @attachments == [] do %>
        <a
          href={@html_url}
          target="_blank"
          rel="noopener noreferrer"
          class="inline-flex items-center gap-1.5 text-xs text-indigo-400 hover:text-indigo-300 transition-colors"
        >
          View submission in Canvas
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="w-3.5 h-3.5"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
            />
          </svg>
        </a>
      <% end %>

      <%= if @comments != [] do %>
        <.submission_comments comments={@comments} />
      <% end %>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp detail_field(assigns) do
    ~H"""
    <div class="rounded-lg bg-slate-900/60 border border-slate-700/40 px-3 py-2">
      <div class="text-[10px] font-semibold text-slate-500 uppercase tracking-wide">{@label}</div>
      <div class="text-xs text-slate-300 mt-0.5 truncate">{@value}</div>
    </div>
    """
  end

  defp student_name(%{user: %{name: name}}) when is_binary(name), do: name
  defp student_name(_), do: "Unknown"

  defp format_score(nil, nil), do: "—"
  defp format_score(nil, grade), do: grade
  defp format_score(score, _grade), do: "#{score}"

  defp format_submission_type(nil), do: "—"
  defp format_submission_type("online_text_entry"), do: "Text Entry"
  defp format_submission_type("online_url"), do: "URL"
  defp format_submission_type("online_upload"), do: "File Upload"
  defp format_submission_type("media_recording"), do: "Media Recording"
  defp format_submission_type("online_quiz"), do: "Quiz"
  defp format_submission_type(other), do: other

  defp format_file_size(bytes) when is_integer(bytes) and bytes < 1024, do: "#{bytes} B"

  defp format_file_size(bytes) when is_integer(bytes) and bytes < 1_048_576,
    do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_file_size(bytes) when is_integer(bytes),
    do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp format_file_size(_), do: ""
end
