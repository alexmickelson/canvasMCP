defmodule CanvasMcp.Canvas.Enrollment do
  require Logger
  alias CanvasMcp.Data.DbHelpers
  alias CanvasMcp.Canvas.Client

  def schema do
    Zoi.object(%{
      id: Zoi.integer(coerce: true),
      user_id: Zoi.integer(coerce: true),
      course_id: Zoi.integer(coerce: true),
      type: Zoi.string(),
      enrollment_state: Zoi.string(),
      role: Zoi.string(),
      created_at: Zoi.string(),
      updated_at: Zoi.string(),
      last_activity_at: Zoi.nullish(Zoi.string()),
      user: Zoi.optional(Zoi.nullish(Zoi.any()))
    })
  end

  def fetch_and_store_for_course(course_id, token) do
    path = "/courses/#{course_id}/enrollments"
    params = [{"per_page", "100"}]

    with {:ok, raw_enrollments} <- Client.get(path, token, params) do
      enrollments =
        Enum.flat_map(raw_enrollments, fn raw ->
          case Zoi.parse(schema(), raw, coerce: true) do
            {:ok, enrollment} ->
              [enrollment]

            {:error, errors} ->
              Logger.warning(
                "Skipping unparseable enrollment #{inspect(Map.get(raw, "id"))}: #{inspect(errors)}"
              )

              []
          end
        end)

      case store_all(enrollments) do
        :ok -> {:ok, enrollments}
        err -> err
      end
    end
  end

  def store(enrollment) do
    sql = """
    INSERT INTO canvas_enrollments (id, course_id, user_id, canvas_object, updated_at)
    VALUES ($(id), $(course_id), $(user_id), $(canvas_object)::jsonb, NOW())
    ON CONFLICT (id) DO UPDATE SET
      course_id     = EXCLUDED.course_id,
      user_id       = EXCLUDED.user_id,
      canvas_object = EXCLUDED.canvas_object,
      updated_at    = EXCLUDED.updated_at
    """

    params = %{
      "id" => enrollment.id,
      "course_id" => enrollment.course_id,
      "user_id" => enrollment.user_id,
      "canvas_object" => enrollment
    }

    case DbHelpers.run_sql(sql, params) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  def store_all([]), do: :ok

  def store_all(enrollments) do
    Enum.reduce_while(enrollments, :ok, fn enrollment, :ok ->
      case store(enrollment) do
        :ok -> {:cont, :ok}
        err -> {:halt, err}
      end
    end)
  end

  def list_for_course(course_id) do
    sql = """
    SELECT canvas_object
    FROM canvas_enrollments
    WHERE course_id = $(course_id)
    ORDER BY updated_at DESC
    """

    case DbHelpers.run_sql(sql, %{"course_id" => course_id}) do
      {:error, reason} -> {:error, reason}
      rows -> {:ok, parse_rows(rows)}
    end
  end

  def list_for_user(user_id) do
    sql = """
    SELECT canvas_object
    FROM canvas_enrollments
    WHERE user_id = $(user_id)
    ORDER BY updated_at DESC
    """

    case DbHelpers.run_sql(sql, %{"user_id" => user_id}) do
      {:error, reason} -> {:error, reason}
      rows -> {:ok, parse_rows(rows)}
    end
  end

  def get_by_id(enrollment_id) do
    sql = "SELECT canvas_object FROM canvas_enrollments WHERE id = $(id)"

    case DbHelpers.run_sql(sql, %{"id" => enrollment_id}) do
      {:error, reason} -> {:error, reason}
      [] -> {:error, :not_found}
      [row | _] -> parse_canvas_object(row)
    end
  end

  def delete_for_course(course_id) do
    sql = "DELETE FROM canvas_enrollments WHERE course_id = $(course_id)"

    case DbHelpers.run_sql(sql, %{"course_id" => course_id}) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  defp parse_rows(rows) do
    Enum.flat_map(rows, fn row ->
      case parse_canvas_object(row) do
        {:ok, enrollment} -> [enrollment]
        _ -> []
      end
    end)
  end

  defp parse_canvas_object(%{"canvas_object" => obj}) do
    case Zoi.parse(schema(), obj, coerce: true) do
      {:ok, enrollment} -> {:ok, enrollment}
      {:error, errors} -> {:error, {:parse_error, errors}}
    end
  end
end
