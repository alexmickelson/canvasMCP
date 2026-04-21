defmodule CanvasMcp.Canvas.Assignment do
  require Logger
  alias CanvasMcp.Data.DbHelpers
  alias CanvasMcp.Canvas.Client

  def schema do
    Zoi.object(%{
      id: Zoi.integer(coerce: true),
      name: Zoi.string(),
      course_id: Zoi.integer(coerce: true),
      description: Zoi.nullish(Zoi.string()),
      due_at: Zoi.nullish(Zoi.string()),
      unlock_at: Zoi.nullish(Zoi.string()),
      lock_at: Zoi.nullish(Zoi.string()),
      points_possible: Zoi.nullish(Zoi.float(coerce: true)),
      grading_type: Zoi.string(),
      submission_types: Zoi.array(Zoi.string()),
      has_submitted_submissions: Zoi.boolean(),
      published: Zoi.boolean(),
      muted: Zoi.boolean(),
      html_url: Zoi.string(),
      grading_standard_id: Zoi.nullish(Zoi.integer(coerce: true)),
      context_module_id: Zoi.nullish(Zoi.integer(coerce: true))
    })
  end

  def fetch_and_store_for_course(course_id, token) do
    path = "/courses/#{course_id}/assignments"

    with {:ok, raw_assignments} <- Client.get(path, token) do
      assignments =
        Enum.flat_map(raw_assignments, fn raw ->
          case Zoi.parse(schema(), raw, coerce: true) do
            {:ok, assignment} ->
              [assignment]

            {:error, errors} ->
              Logger.warning(
                "Skipping unparseable assignment #{inspect(Map.get(raw, "id"))}: #{inspect(errors)}"
              )

              []
          end
        end)

      case store_all(assignments) do
        :ok -> {:ok, assignments}
        err -> err
      end
    end
  end

  def store(assignment) do
    sql = """
    INSERT INTO canvas_assignments (id, course_id, canvas_object, updated_at)
    VALUES ($(id), $(course_id), $(canvas_object)::jsonb, NOW())
    ON CONFLICT (id) DO UPDATE SET
      course_id     = EXCLUDED.course_id,
      canvas_object = EXCLUDED.canvas_object,
      updated_at    = EXCLUDED.updated_at
    """

    params = %{
      "id" => assignment.id,
      "course_id" => assignment.course_id,
      "canvas_object" => assignment
    }

    case DbHelpers.run_sql(sql, params) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  def store_all([]), do: :ok

  def store_all(assignments) do
    Enum.reduce_while(assignments, :ok, fn assignment, :ok ->
      case store(assignment) do
        :ok -> {:cont, :ok}
        err -> {:halt, err}
      end
    end)
  end

  def list_for_course(course_id) do
    sql = """
    SELECT canvas_object
    FROM canvas_assignments
    WHERE course_id = $(course_id)
    ORDER BY updated_at DESC
    """

    case DbHelpers.run_sql(sql, %{"course_id" => course_id}) do
      {:error, reason} -> {:error, reason}
      rows -> {:ok, parse_rows(rows)}
    end
  end

  def get_by_id(assignment_id) do
    sql = "SELECT canvas_object FROM canvas_assignments WHERE id = $(id)"

    case DbHelpers.run_sql(sql, %{"id" => assignment_id}) do
      {:error, reason} -> {:error, reason}
      [] -> {:error, :not_found}
      [row | _] -> parse_canvas_object(row)
    end
  end

  # ---------------------------------------------------------------------------
  # DB — delete
  # ---------------------------------------------------------------------------

  def delete_for_course(course_id) do
    sql = "DELETE FROM canvas_assignments WHERE course_id = $(course_id)"

    case DbHelpers.run_sql(sql, %{"course_id" => course_id}) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  def delete(assignment_id) do
    sql = "DELETE FROM canvas_assignments WHERE id = $(id)"

    case DbHelpers.run_sql(sql, %{"id" => assignment_id}) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  defp parse_rows(rows) do
    Enum.flat_map(rows, fn row ->
      case parse_canvas_object(row) do
        {:ok, assignment} -> [assignment]
        _ -> []
      end
    end)
  end

  defp parse_canvas_object(%{"canvas_object" => obj}) do
    case Zoi.parse(schema(), obj, coerce: true) do
      {:ok, assignment} -> {:ok, assignment}
      {:error, errors} -> {:error, {:parse_error, errors}}
    end
  end
end
