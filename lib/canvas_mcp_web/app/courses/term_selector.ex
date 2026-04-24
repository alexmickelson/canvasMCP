defmodule CanvasMcpWeb.App.Courses.TermSelector do
  use Phoenix.Component

  @season_order %{"Spring" => 1, "Rings" => 2, "Summer" => 3, "Fall" => 4}

  def group_by_semester(courses) do
    courses
    |> Enum.group_by(fn course ->
      case course[:term] do
        %{name: name} when is_binary(name) and name != "" -> name
        _ -> "Default"
      end
    end)
    |> Enum.sort_by(fn {name, _} -> semester_sort_key(name) end, :desc)
  end

  def default_term([]), do: nil

  def default_term(courses) do
    today = Date.utc_today()
    grouped = group_by_semester(courses)

    terms_by_name =
      courses
      |> Enum.flat_map(fn course ->
        case course[:term] do
          %{name: name} = term when is_binary(name) and name != "" -> [{name, term}]
          _ -> []
        end
      end)
      |> Enum.uniq_by(fn {name, _} -> name end)
      |> Map.new()

    by_dates =
      Enum.find(grouped, fn {name, _} ->
        term_active_by_dates?(Map.get(terms_by_name, name), today)
      end)

    case by_dates do
      {name, _} ->
        name

      nil ->
        by_name =
          Enum.find(grouped, fn {name, _} -> term_active_by_name?(name, today) end)

        case by_name do
          {name, _} -> name
          nil -> elem(List.first(grouped), 0)
        end
    end
  end

  defp term_active_by_dates?(nil, _today), do: false

  defp term_active_by_dates?(term, today) do
    with start_at when not is_nil(start_at) <- term[:start_at],
         end_at when not is_nil(end_at) <- term[:end_at],
         {:ok, start_dt, _} <- DateTime.from_iso8601(start_at),
         {:ok, end_dt, _} <- DateTime.from_iso8601(end_at) do
      Date.compare(today, DateTime.to_date(start_dt)) != :lt and
        Date.compare(today, DateTime.to_date(end_dt)) != :gt
    else
      _ -> false
    end
  end

  defp term_active_by_name?(name, today) do
    case String.split(name, " ", parts: 2) do
      [season, year_str] ->
        case Integer.parse(year_str) do
          {year, ""} when year == today.year -> season_includes_month?(season, today.month)
          _ -> false
        end

      _ ->
        false
    end
  end

  defp season_includes_month?("Spring", m), do: m in 1..5
  defp season_includes_month?("Summer", m), do: m in 6..8
  defp season_includes_month?("Fall", m), do: m in 8..12
  defp season_includes_month?(_, _m), do: false

  defp semester_sort_key("Default"), do: {-1, -1}

  defp semester_sort_key(name) do
    case String.split(name, " ", parts: 2) do
      [season, year_str] ->
        case Integer.parse(year_str) do
          {year, ""} -> {year, Map.get(@season_order, season, 0)}
          _ -> {0, 0}
        end

      _ ->
        {0, 0}
    end
  end

  attr :terms, :list, required: true
  attr :active_term, :string, default: nil

  def term_selector(assigns) do
    ~H"""
    <%= if @terms != [] do %>
      <div class="flex items-center gap-2 flex-wrap">
        <%= for term <- @terms do %>
          <button
            type="button"
            phx-click="select_term"
            phx-value-term={term}
            class={[
              "px-4 py-1.5 rounded-full text-xs font-semibold transition-all duration-150",
              @active_term == term &&
                "bg-indigo-600 text-white shadow-sm shadow-indigo-900/50",
              @active_term != term &&
                "bg-slate-800 border border-slate-700 text-slate-400 hover:border-slate-500 hover:text-slate-200 hover:bg-slate-700/60"
            ]}
          >
            {term}
          </button>
        <% end %>
      </div>
    <% end %>
    """
  end
end
