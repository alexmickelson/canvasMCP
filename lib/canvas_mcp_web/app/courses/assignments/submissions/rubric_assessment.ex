defmodule CanvasMcpWeb.App.Courses.Submissions.RubricAssessment do
  use Phoenix.Component

  attr :rubric, :any, required: true
  attr :assessment, :any, required: true

  def rubric_assessment(assigns) do
    total_pts =
      Enum.reduce(assigns.rubric.data, 0.0, fn criterion, acc ->
        case Map.get(assigns.assessment, criterion.id) do
          %{"points" => pts} when is_number(pts) -> acc + pts
          _ -> acc
        end
      end)

    assigns = assign(assigns, :total_pts, total_pts)

    ~H"""
    <div class="space-y-3">
      <div class="flex items-center justify-between gap-2">
        <h4 class="text-xs font-semibold text-slate-400 uppercase tracking-wide">Rubric</h4>
        <span class="text-xs font-mono text-slate-400">
          {format_float(@total_pts)} / {format_float(@rubric.points_possible)} pts
        </span>
      </div>
      <div class="space-y-2">
        <%= for criterion <- @rubric.data do %>
          <% crit = Map.get(@assessment, criterion.id) %>
          <div class="rounded-lg bg-slate-900/60 border border-slate-700/40 px-3 py-2.5 space-y-1.5">
            <div class="flex items-start justify-between gap-3">
              <span class="text-xs font-medium text-slate-300 leading-snug">
                {criterion.description}
              </span>
              <span class={[
                "text-xs font-mono shrink-0",
                crit && Map.get(crit, "points") == criterion.points && "text-emerald-400",
                crit && Map.get(crit, "points") != criterion.points && "text-slate-300",
                !crit && "text-slate-500"
              ]}>
                {format_criterion_score(crit)} / {format_float(criterion.points)}
              </span>
            </div>
            <%= if crit do %>
              <% matched = Enum.find(criterion.ratings, &(&1.id == Map.get(crit, "rating_id"))) %>
              <%= if matched do %>
                <div class="text-[11px] text-indigo-400 font-medium">{matched.description}</div>
              <% end %>
              <%= if Map.get(crit, "comments") not in [nil, ""] do %>
                <div class="text-[11px] text-slate-400 italic">
                  &ldquo;{Map.get(crit, "comments")}&rdquo;
                </div>
              <% end %>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_float(f) when is_float(f) do
    if f == Float.floor(f), do: "#{trunc(f)}", else: "#{f}"
  end

  defp format_float(i) when is_integer(i), do: "#{i}"
  defp format_float(_), do: "—"

  defp format_criterion_score(nil), do: "—"
  defp format_criterion_score(%{"points" => pts}) when is_number(pts), do: format_float(pts)
  defp format_criterion_score(_), do: "—"
end
