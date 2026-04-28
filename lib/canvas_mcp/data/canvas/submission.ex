defmodule CanvasMcp.Canvas.Submission do
  require Logger
  alias CanvasMcp.Data.DbHelpers
  alias CanvasMcp.Canvas.Client

  def schema do
    Zoi.object(%{
      id: Zoi.integer(coerce: true),
      assignment_id: Zoi.integer(coerce: true),
      user_id: Zoi.integer(coerce: true),
      workflow_state: Zoi.string(),
      score: Zoi.nullish(Zoi.float(coerce: true)),
      grade: Zoi.nullish(Zoi.string()),
      entered_grade: Zoi.nullish(Zoi.string()),
      entered_score: Zoi.nullish(Zoi.float(coerce: true)),
      submitted_at: Zoi.nullish(Zoi.string()),
      graded_at: Zoi.nullish(Zoi.string()),
      late: Zoi.nullish(Zoi.boolean()),
      missing: Zoi.nullish(Zoi.boolean()),
      excused: Zoi.nullish(Zoi.boolean()),
      attempt: Zoi.nullish(Zoi.integer(coerce: true)),
      body: Zoi.nullish(Zoi.string()),
      html_url: Zoi.nullish(Zoi.string()),
      submission_type: Zoi.nullish(Zoi.string()),
      user:
        Zoi.object(%{
          id: Zoi.integer(coerce: true),
          name: Zoi.string(),
          sortable_name: Zoi.nullish(Zoi.string()),
          short_name: Zoi.nullish(Zoi.string()),
          login_id: Zoi.nullish(Zoi.string()),
          sis_user_id: Zoi.nullish(Zoi.string())
        }),
      submission_comments: Zoi.optional(Zoi.nullish(Zoi.list(Zoi.any()))),
      rubric_assessment: Zoi.optional(Zoi.nullish(Zoi.any())),
      attachments: Zoi.optional(Zoi.nullish(Zoi.list(Zoi.any())))
    })
  end

  def fetch_and_store_for_assignment(course_id, assignment_id, token) do
    path = "/courses/#{course_id}/assignments/#{assignment_id}/submissions"

    params = [
      {"include[]", "user"},
      {"include[]", "submission_comments"},
      {"include[]", "rubric_assessment"}
    ]

    with {:ok, raw_submissions} <- Client.get(path, token, params) do
      submissions =
        raw_submissions
        |> Enum.reject(fn raw ->
          get_in(raw, ["user", "name"]) == "Test Student"
        end)
        |> Enum.flat_map(fn raw ->
          case Zoi.parse(schema(), raw, coerce: true) do
            {:ok, submission} ->
              [submission]

            {:error, errors} ->
              Logger.warning(
                "Skipping unparseable submission #{inspect(Map.get(raw, "id"))}: #{inspect(errors)}"
              )

              []
          end
        end)

      case store_all(submissions) do
        :ok -> {:ok, submissions}
        err -> err
      end
    end
  end

  def fetch_and_store_one(course_id, assignment_id, user_id, token) do
    path = "/courses/#{course_id}/assignments/#{assignment_id}/submissions/#{user_id}"

    params = [
      {"include[]", "user"},
      {"include[]", "submission_comments"},
      {"include[]", "rubric_assessment"}
    ]

    with {:ok, raw} <- Client.get_one(path, token, params) do
      case Zoi.parse(schema(), raw, coerce: true) do
        {:ok, submission} ->
          case store(submission) do
            :ok -> {:ok, submission}
            err -> err
          end

        {:error, errors} ->
          Logger.error(
            "Failed to parse submission #{inspect(Map.get(raw, "id"))}: #{inspect(errors)}"
          )

          {:error, {:parse_error, errors}}
      end
    end
  end

  def store(submission) do
    sql = """
    INSERT INTO canvas_submissions (id, assignment_id, user_id, workflow_state, canvas_object, updated_at)
    VALUES ($(id), $(assignment_id), $(user_id), $(workflow_state), $(canvas_object)::jsonb, NOW())
    ON CONFLICT (id) DO UPDATE SET
      assignment_id  = EXCLUDED.assignment_id,
      user_id        = EXCLUDED.user_id,
      workflow_state = EXCLUDED.workflow_state,
      canvas_object  = EXCLUDED.canvas_object,
      updated_at     = EXCLUDED.updated_at
    """

    params = %{
      "id" => submission.id,
      "assignment_id" => submission.assignment_id,
      "user_id" => submission.user_id,
      "workflow_state" => submission.workflow_state,
      "canvas_object" => submission
    }

    case DbHelpers.run_sql(sql, params) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  def store_all([]), do: :ok

  def store_all(submissions) do
    Enum.reduce_while(submissions, :ok, fn submission, :ok ->
      case store(submission) do
        :ok -> {:cont, :ok}
        err -> {:halt, err}
      end
    end)
  end

  def list_for_assignment(assignment_id, canvas_user_id) do
    sql = """
    SELECT s.canvas_object
    FROM canvas_submissions s
    JOIN canvas_assignments a ON a.id = s.assignment_id
    JOIN canvas_courses c ON c.id = a.course_id
    WHERE s.assignment_id = $(assignment_id)
      AND c.canvas_user_id = $(canvas_user_id)
    ORDER BY s.id DESC
    """

    case DbHelpers.run_sql(sql, %{
           "assignment_id" => assignment_id,
           "canvas_user_id" => canvas_user_id
         }) do
      {:error, reason} -> {:error, reason}
      rows -> {:ok, parse_rows(rows)}
    end
  end

  def list_ungraded_for_assignment(assignment_id, canvas_user_id) do
    sql = """
    SELECT s.canvas_object
    FROM canvas_submissions s
    JOIN canvas_assignments a ON a.id = s.assignment_id
    JOIN canvas_courses c ON c.id = a.course_id
    WHERE s.assignment_id = $(assignment_id)
      AND s.workflow_state = 'submitted'
      AND c.canvas_user_id = $(canvas_user_id)
    ORDER BY s.id DESC
    """

    case DbHelpers.run_sql(sql, %{
           "assignment_id" => assignment_id,
           "canvas_user_id" => canvas_user_id
         }) do
      {:error, reason} -> {:error, reason}
      rows -> {:ok, parse_rows(rows)}
    end
  end

  def get_by_id(submission_id, canvas_user_id) do
    sql = """
    SELECT s.canvas_object
    FROM canvas_submissions s
    JOIN canvas_assignments a ON a.id = s.assignment_id
    JOIN canvas_courses c ON c.id = a.course_id
    WHERE s.id = $(id)
      AND c.canvas_user_id = $(canvas_user_id)
    """

    case DbHelpers.run_sql(sql, %{"id" => submission_id, "canvas_user_id" => canvas_user_id}) do
      {:error, reason} -> {:error, reason}
      [] -> {:error, :not_found}
      [row | _] -> parse_canvas_object(row)
    end
  end

  def get_for_student(assignment_id, user_id, canvas_user_id) do
    sql = """
    SELECT s.canvas_object
    FROM canvas_submissions s
    JOIN canvas_assignments a ON a.id = s.assignment_id
    JOIN canvas_courses c ON c.id = a.course_id
    WHERE s.assignment_id = $(assignment_id)
      AND s.user_id = $(user_id)
      AND c.canvas_user_id = $(canvas_user_id)
    """

    case DbHelpers.run_sql(sql, %{
           "assignment_id" => assignment_id,
           "user_id" => user_id,
           "canvas_user_id" => canvas_user_id
         }) do
      {:error, reason} -> {:error, reason}
      [] -> {:error, :not_found}
      [row | _] -> parse_canvas_object(row)
    end
  end

  def delete_for_assignment(assignment_id, canvas_user_id) do
    sql = """
    DELETE FROM canvas_submissions
    WHERE assignment_id = $(assignment_id)
      AND assignment_id IN (
        SELECT a.id FROM canvas_assignments a
        JOIN canvas_courses c ON c.id = a.course_id
        WHERE c.canvas_user_id = $(canvas_user_id)
      )
    """

    case DbHelpers.run_sql(sql, %{
           "assignment_id" => assignment_id,
           "canvas_user_id" => canvas_user_id
         }) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  defp parse_rows(rows) do
    Enum.flat_map(rows, fn row ->
      case parse_canvas_object(row) do
        {:ok, submission} -> [submission]
        _ -> []
      end
    end)
  end

  defp parse_canvas_object(%{"canvas_object" => obj}) do
    case Zoi.parse(schema(), obj, coerce: true) do
      {:ok, submission} -> {:ok, submission}
      {:error, errors} -> {:error, {:parse_error, errors}}
    end
  end
end
