defmodule CanvasMcpWeb.App.Courses.CourseCalendar do
  use Phoenix.Component
  import CanvasMcpWeb.App.Courses.AssignmentInCalendarDay
  import CanvasMcpWeb.DateHelpers

  @day_names ~w(Sun Mon Tue Wed Thu Fri Sat)
  @month_names ~w(January February March April May June July August September October November December)

  attr :assignments, :list, required: true
  attr :course_id, :integer, required: true
  attr :submissions_map, :map, default: %{}
  attr :active_student_ids, :any, default: nil

  def course_calendar(assigns) do
    months = build_months(assigns.assignments)

    assigns =
      assigns
      |> assign(:months, months)
      |> assign(:day_names, @day_names)

    ~H"""
    <%= if @months == [] do %>
      <div class="rounded-2xl border border-slate-700 border-dashed bg-slate-800/40 px-6 py-14 text-center">
        <p class="text-sm text-slate-500">No due dates to display.</p>
      </div>
    <% else %>
      <div class="space-y-8">
        <%= for {month_label, weeks} <- @months do %>
          <div>
            <h3 class="text-xs font-semibold text-slate-500 uppercase tracking-widest mb-3">
              {month_label}
            </h3>
            <%!-- Day header row --%>
            <div class="grid grid-cols-7 ">
              <%= for day <- @day_names do %>
                <div class="px-2 py-2 text-center text-xs font-medium text-slate-500">
                  {day}
                </div>
              <% end %>
            </div>
            <div class="rounded-xl border border-slate-900">
              <%!-- Week rows --%>
              <%= for {week_days, week_idx} <- Enum.with_index(weeks) do %>
                <div class="grid grid-cols-7">
                  <%= for {{date, day_assignments}, day_idx} <- Enum.with_index(week_days) do %>
                    <div class={[
                      "min-h-[72px] p-2 flex flex-col gap-1",
                      is_nil(date) && "bg-slate-900/40",
                      !is_nil(date) && date == Date.utc_today() && "bg-indigo-950/40",
                      day_idx < 6 && "border-r border-slate-700",
                      week_idx < length(weeks) - 1 && "border-b border-slate-700"
                    ]}>
                      <%= if date do %>
                        <span class={[
                          "self-start text-sm font-medium w-6 h-6 flex items-center justify-center",
                          date == Date.utc_today() &&
                            "rounded-lg bg-indigo-500 text-white shadow-sm shadow-indigo-500/40",
                          date != Date.utc_today() &&
                            "rounded-md text-slate-500"
                        ]}>
                          {date.day}
                        </span>
                        <%= for assignment <- day_assignments do %>
                          <.assignment_in_calendar_day
                            assignment={assignment}
                            course_id={@course_id}
                            submissions={Map.get(@submissions_map, assignment.id, [])}
                            active_student_ids={@active_student_ids}
                          />
                        <% end %>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp build_months([]), do: []

  defp build_months(assignments) do
    by_date =
      assignments
      |> Enum.flat_map(fn a ->
        case parse_date(a.due_at) do
          {:ok, date} -> [{date, a}]
          _ -> []
        end
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    if map_size(by_date) == 0 do
      []
    else
      dates = Map.keys(by_date)
      first = dates |> Enum.min(Date) |> week_start()
      last = dates |> Enum.max(Date) |> week_end()

      first
      |> weeks_between(last)
      |> Enum.map(fn week ->
        week_days = Enum.map(week, fn date -> {date, Map.get(by_date, date, [])} end)
        {week, week_days}
      end)
      |> Enum.group_by(fn {[sunday | _], _} -> {sunday.year, sunday.month} end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {{year, month}, week_tuples} ->
        label = "#{Enum.at(@month_names, month - 1)} #{year}"
        weeks = Enum.map(week_tuples, &elem(&1, 1))
        {label, weeks}
      end)
    end
  end

  defp parse_date(nil), do: :error

  defp parse_date(iso), do: local_date(iso)

  # Sunday of the week containing `date` (weeks run Sun–Sat)
  defp week_start(date) do
    # Date.day_of_week: Mon=1 … Sat=6, Sun=7
    # rem(day_of_week, 7) gives offset back to Sunday: Sun→0, Mon→1 … Sat→6
    day_of_week = Date.day_of_week(date)
    Date.add(date, -rem(day_of_week, 7))
  end

  # Saturday of the week containing `date`
  defp week_end(date) do
    day_of_week = Date.day_of_week(date)
    Date.add(date, rem(13 - day_of_week, 7))
  end

  # List of weeks (each week = list of 7 dates Mon..Sun) from `from` to `to`
  defp weeks_between(from, to) do
    Stream.iterate(from, &Date.add(&1, 7))
    |> Stream.take_while(&(Date.compare(&1, to) != :gt))
    |> Enum.map(fn monday ->
      Enum.map(0..6, &Date.add(monday, &1))
    end)
  end
end
