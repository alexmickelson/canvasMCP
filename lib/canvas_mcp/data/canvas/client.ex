defmodule CanvasMcp.Canvas.Client do
  require Logger

  defp base_url, do: System.get_env("CANVAS_BASE_URL", "https://snow.instructure.com")

  def get(path, token, params \\ []) do
    url = base_url() <> "/api/v1" <> path
    all_params = [{"per_page", "100"} | List.wrap(params)]
    do_paginated_get(url, all_params, auth_headers(token), [])
  end

  def get_one(path, token, params \\ []) do
    url = base_url() <> "/api/v1" <> path

    case Req.get(url, headers: auth_headers(token), params: params) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Canvas API #{path} returned #{status}: #{inspect(body)}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.error("Canvas API request to #{path} failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp do_paginated_get(url, params, headers, acc) do
    case Req.get(url, headers: headers, params: params) do
      {:ok, %{status: 200, body: body} = resp} ->
        items = acc ++ body

        case next_url(resp) do
          nil -> {:ok, items}
          next -> do_paginated_get(next, [], headers, items)
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error("Canvas API returned #{status}: #{inspect(body)}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.error("Canvas API request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp auth_headers(token) do
    %{"authorization" => "Bearer #{token}"}
  end

  defp next_url(resp) do
    case Req.Response.get_header(resp, "link") do
      [] ->
        nil

      [link_header | _] ->
        link_header
        |> String.split(",")
        |> Enum.find_value(fn part ->
          if String.contains?(part, ~S|rel="next"|) do
            part
            |> String.split(";")
            |> hd()
            |> String.trim()
            |> String.trim_leading("<")
            |> String.trim_trailing(">")
          end
        end)
    end
  end
end
