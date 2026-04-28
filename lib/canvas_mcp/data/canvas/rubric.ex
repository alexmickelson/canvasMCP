defmodule CanvasMcp.Canvas.Rubric do
  require Logger
  alias CanvasMcp.Data.DbHelpers
  alias CanvasMcp.Canvas.Client

  def schema do
    Zoi.object(%{
      id: Zoi.integer(coerce: true),
      title: Zoi.string(),
      context_id: Zoi.integer(coerce: true),
      context_type: Zoi.string(),
      points_possible: Zoi.float(coerce: true),
      reusable: Zoi.optional(Zoi.boolean()),
      read_only: Zoi.optional(Zoi.boolean()),
      free_form_criterion_comments: Zoi.nullish(Zoi.boolean()),
      hide_score_total: Zoi.nullish(Zoi.boolean()),
      data:
        Zoi.list(
          Zoi.object(
            %{
              id: Zoi.string(),
              description: Zoi.optional(Zoi.string()),
              long_description: Zoi.optional(Zoi.string()),
              points: Zoi.float(coerce: true),
              criterion_use_range: Zoi.optional(Zoi.boolean()),
              ratings:
                Zoi.list(
                  Zoi.object(
                    %{
                      id: Zoi.string(),
                      description: Zoi.optional(Zoi.string()),
                      long_description: Zoi.optional(Zoi.string()),
                      points: Zoi.float(coerce: true)
                    },
                    coerce: true
                  )
                )
            },
            coerce: true
          )
        )
    })
  end

  def fetch_and_store_for_assignment(course_id, assignment_id, token) do
    with {:ok, assignment_raw} <-
           Client.get_one("/courses/#{course_id}/assignments/#{assignment_id}", token),
         {:ok, rubric_id} <- extract_rubric_id(assignment_raw),
         {:ok, raw_rubric} <-
           Client.get_one("/courses/#{course_id}/rubrics/#{rubric_id}", token) do
      case Zoi.parse(schema(), raw_rubric, coerce: true) do
        {:ok, rubric} ->
          case store(rubric, course_id, assignment_id) do
            :ok -> {:ok, rubric}
            err -> err
          end

        {:error, errors} ->
          Logger.error(
            "Failed to parse rubric #{rubric_id}: #{inspect(errors)}\nRaw data[0]: #{inspect(raw_rubric["data"] && List.first(raw_rubric["data"]))}"
          )

          {:error, {:parse_error, errors}}
      end
    end
  end

  def fetch_and_store_for_course(course_id, token) do
    with {:ok, raw_rubrics} <- Client.get("/courses/#{course_id}/rubrics", token) do
      rubrics =
        Enum.flat_map(raw_rubrics, fn raw ->
          case Zoi.parse(schema(), raw, coerce: true) do
            {:ok, rubric} ->
              [rubric]

            {:error, errors} ->
              Logger.warning(
                "Skipping unparseable rubric #{inspect(Map.get(raw, "id"))}: #{inspect(errors)}"
              )

              []
          end
        end)

      case store_all(rubrics, course_id) do
        :ok -> {:ok, rubrics}
        err -> err
      end
    end
  end

  def store(rubric, course_id, assignment_id \\ nil) do
    sql = """
    INSERT INTO canvas_rubrics (id, course_id, assignment_id, canvas_object, updated_at)
    VALUES ($(id), $(course_id), $(assignment_id), $(canvas_object)::jsonb, NOW())
    ON CONFLICT (id) DO UPDATE SET
      course_id     = EXCLUDED.course_id,
      assignment_id = COALESCE(EXCLUDED.assignment_id, canvas_rubrics.assignment_id),
      canvas_object = EXCLUDED.canvas_object,
      updated_at    = EXCLUDED.updated_at
    """

    params = %{
      "id" => rubric.id,
      "course_id" => course_id,
      "assignment_id" => assignment_id,
      "canvas_object" => rubric
    }

    case DbHelpers.run_sql(sql, params) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  def store_all([], _course_id), do: :ok

  def store_all(rubrics, course_id) do
    Enum.reduce_while(rubrics, :ok, fn rubric, :ok ->
      case store(rubric, course_id) do
        :ok -> {:cont, :ok}
        err -> {:halt, err}
      end
    end)
  end

  def list_for_course(course_id, canvas_user_id) do
    sql = """
    SELECT r.canvas_object
    FROM canvas_rubrics r
    JOIN canvas_courses c ON c.id = r.course_id
    WHERE r.course_id = $(course_id)
      AND c.canvas_user_id = $(canvas_user_id)
    ORDER BY r.updated_at DESC
    """

    case DbHelpers.run_sql(sql, %{"course_id" => course_id, "canvas_user_id" => canvas_user_id}) do
      {:error, reason} -> {:error, reason}
      rows -> {:ok, parse_rows(rows)}
    end
  end

  def get_for_assignment(assignment_id, canvas_user_id) do
    sql = """
    SELECT r.canvas_object
    FROM canvas_rubrics r
    JOIN canvas_assignments a ON a.id = r.assignment_id
    JOIN canvas_courses c ON c.id = a.course_id
    WHERE r.assignment_id = $(assignment_id)
      AND c.canvas_user_id = $(canvas_user_id)
    """

    case DbHelpers.run_sql(sql, %{
           "assignment_id" => assignment_id,
           "canvas_user_id" => canvas_user_id
         }) do
      {:error, reason} -> {:error, reason}
      [] -> {:error, :not_found}
      [row | _] -> parse_canvas_object(row)
    end
  end

  def get_by_id(rubric_id, canvas_user_id) do
    sql = """
    SELECT r.canvas_object
    FROM canvas_rubrics r
    JOIN canvas_courses c ON c.id = r.course_id
    WHERE r.id = $(id)
      AND c.canvas_user_id = $(canvas_user_id)
    """

    case DbHelpers.run_sql(sql, %{"id" => rubric_id, "canvas_user_id" => canvas_user_id}) do
      {:error, reason} -> {:error, reason}
      [] -> {:error, :not_found}
      [row | _] -> parse_canvas_object(row)
    end
  end

  def delete_for_course(course_id, canvas_user_id) do
    sql = """
    DELETE FROM canvas_rubrics
    WHERE course_id = $(course_id)
      AND course_id IN (
        SELECT id FROM canvas_courses WHERE canvas_user_id = $(canvas_user_id)
      )
    """

    case DbHelpers.run_sql(sql, %{"course_id" => course_id, "canvas_user_id" => canvas_user_id}) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  defp extract_rubric_id(%{"rubric_settings" => %{"id" => rubric_id}})
       when not is_nil(rubric_id),
       do: {:ok, rubric_id}

  defp extract_rubric_id(%{"rubric_id" => rubric_id})
       when not is_nil(rubric_id),
       do: {:ok, rubric_id}

  defp extract_rubric_id(_raw), do: {:error, :no_rubric}

  defp parse_rows(rows) do
    Enum.flat_map(rows, fn row ->
      case parse_canvas_object(row) do
        {:ok, rubric} -> [rubric]
        _ -> []
      end
    end)
  end

  defp parse_canvas_object(%{"canvas_object" => obj}) do
    case Zoi.parse(schema(), obj, coerce: true) do
      {:ok, rubric} -> {:ok, rubric}
      {:error, errors} -> {:error, {:parse_error, errors}}
    end
  end
end
