defmodule CanvasMcp.Canvas.Course do
  require Logger
  alias CanvasMcp.Data.DbHelpers
  alias CanvasMcp.Canvas.Client

  def schema do
    Zoi.object(%{
      id: Zoi.integer(coerce: true),
      name: Zoi.string(),
      course_code: Zoi.string(),
      workflow_state: Zoi.string(),
      enrollment_term_id: Zoi.integer(coerce: true),
      term:
        Zoi.optional(
          Zoi.object(%{
            id: Zoi.integer(coerce: true),
            name: Zoi.string(),
            start_at: Zoi.nullish(Zoi.string()),
            end_at: Zoi.nullish(Zoi.string())
          })
        ),
      hide_final_grades: Zoi.boolean(),
      public_description: Zoi.nullish(Zoi.string()),
      total_students: Zoi.nullish(Zoi.integer(coerce: true)),
      needs_grading_count: Zoi.nullish(Zoi.integer(coerce: true)),
      access_restricted_by_date: Zoi.nullish(Zoi.boolean())
    })
  end

  def get_all_courses(token, invalidate_cache, canvas_user_id)

  def get_all_courses(_token, false, canvas_user_id), do: list_all(canvas_user_id)

  def get_all_courses(token, true, canvas_user_id) do
    with {:ok, raw_courses} <- Client.get("/courses", token, [{"include[]", "term"}]) do
      courses =
        raw_courses
        |> Enum.reject(&Map.get(&1, "access_restricted_by_date"))
        |> Enum.flat_map(fn raw ->
          case Zoi.parse(schema(), raw, coerce: true) do
            {:ok, course} ->
              [course]

            {:error, errors} ->
              Logger.warning(
                "Skipping unparseable course #{inspect(Map.get(raw, "id"))}: #{inspect(errors)}"
              )

              []
          end
        end)

      case store_all(courses, canvas_user_id) do
        :ok -> {:ok, courses}
        err -> err
      end
    end
  end

  def store(course, canvas_user_id) do
    term = Map.get(course, :term)

    sql = """
    INSERT INTO canvas_courses (id, canvas_user_id, term_id, term_name, canvas_object, updated_at)
    VALUES ($(id), $(canvas_user_id), $(term_id), $(term_name), $(canvas_object)::jsonb, NOW())
    ON CONFLICT (id) DO UPDATE SET
      canvas_user_id = EXCLUDED.canvas_user_id,
      term_id       = EXCLUDED.term_id,
      term_name     = EXCLUDED.term_name,
      canvas_object = EXCLUDED.canvas_object,
      updated_at    = EXCLUDED.updated_at
    """

    params = %{
      "id" => course.id,
      "canvas_user_id" => canvas_user_id,
      "term_id" => term && term.id,
      "term_name" => term && term.name,
      "canvas_object" => course
    }

    case DbHelpers.run_sql(sql, params) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  def store_all([], _canvas_user_id), do: :ok

  def store_all(courses, canvas_user_id) do
    Enum.reduce_while(courses, :ok, fn course, :ok ->
      case store(course, canvas_user_id) do
        :ok -> {:cont, :ok}
        err -> {:halt, err}
      end
    end)
  end

  def list_all(canvas_user_id) do
    sql = """
    SELECT canvas_object FROM canvas_courses
    WHERE canvas_user_id = $(canvas_user_id)
    ORDER BY updated_at DESC
    """

    case DbHelpers.run_sql(sql, %{"canvas_user_id" => canvas_user_id}) do
      {:error, reason} -> {:error, reason}
      rows -> {:ok, parse_rows(rows)}
    end
  end

  def get_by_id(course_id, canvas_user_id) do
    sql = """
    SELECT canvas_object FROM canvas_courses
    WHERE id = $(id) AND canvas_user_id = $(canvas_user_id)
    """

    case DbHelpers.run_sql(sql, %{"id" => course_id, "canvas_user_id" => canvas_user_id}) do
      {:error, reason} -> {:error, reason}
      [] -> {:error, :not_found}
      [row | _] -> parse_canvas_object(row)
    end
  end

  def delete(course_id, canvas_user_id) do
    sql = "DELETE FROM canvas_courses WHERE id = $(id) AND canvas_user_id = $(canvas_user_id)"

    case DbHelpers.run_sql(sql, %{"id" => course_id, "canvas_user_id" => canvas_user_id}) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  def delete_all do
    sql = "DELETE FROM canvas_courses"

    case DbHelpers.run_sql(sql, %{}) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  defp parse_rows(rows) do
    Enum.flat_map(rows, fn row ->
      case parse_canvas_object(row) do
        {:ok, course} -> [course]
        _ -> []
      end
    end)
  end

  defp parse_canvas_object(%{"canvas_object" => obj}) do
    case Zoi.parse(schema(), obj, coerce: true) do
      {:ok, course} -> {:ok, course}
      {:error, errors} -> {:error, {:parse_error, errors}}
    end
  end
end
