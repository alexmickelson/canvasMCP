defmodule CanvasMcpWeb.DateHelpers do
  @moduledoc false

  @timezone "America/Denver"

  @doc """
  Parse a Canvas ISO 8601 UTC datetime string and return a `Date` in
  the America/Denver timezone. Returns `:error` for nil or unparseable input.
  """
  def local_date(nil), do: :error

  def local_date(iso) do
    with {:ok, dt, _} <- DateTime.from_iso8601(iso),
         {:ok, local} <- DateTime.shift_zone(dt, @timezone) do
      {:ok, DateTime.to_date(local)}
    else
      _ -> :error
    end
  end

  @doc """
  Format a Canvas ISO 8601 UTC datetime string as a human-readable string in
  the America/Denver timezone, e.g. "Apr 25, 2026 at 11:59 PM MDT".
  Returns "—" for nil or unparseable input.
  """
  def format_datetime(nil), do: "—"

  def format_datetime(iso) do
    with {:ok, dt, _} <- DateTime.from_iso8601(iso),
         {:ok, local} <- DateTime.shift_zone(dt, @timezone) do
      abbr = local.zone_abbr
      hour12 = rem(local.hour, 12) |> then(fn h -> if h == 0, do: 12, else: h end)
      am_pm = if local.hour < 12, do: "AM", else: "PM"
      minute = String.pad_leading("#{local.minute}", 2, "0")

      "#{month_abbr(local.month)} #{local.day}, #{local.year} at #{hour12}:#{minute} #{am_pm} #{abbr}"
    else
      _ -> iso
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
