defmodule CanvasMcpWeb.Api.Submissions.SubmissionsController do
  use CanvasMcpWeb, :controller
  alias CanvasMcp.Data.ServiceAccount

  # ---------------------------------------------------------------------------
  # OpenAPI metadata — consumed by CanvasMcpWeb.Api.OpenApi to build the spec.
  # ---------------------------------------------------------------------------

  def openapi_schemas do
    %{
      "SubmissionListItem" => %{
        type: "object",
        properties: %{
          submission_id: %{type: "integer", example: 111_222},
          assignment_id: %{type: "integer", example: 987_654},
          student_name: %{type: "string", nullable: true, example: "Jane Student"},
          student_id: %{type: "integer", example: 555_666},
          workflow_state: %{type: "string", example: "graded"},
          score: %{type: "string", nullable: true, example: "95/100"},
          posted_grade: %{type: "string", nullable: true, example: "95"},
          submitted_at: %{type: "string", format: "date-time", nullable: true},
          submitted_at_formatted: %{type: "string", nullable: true, example: "2 hours before due"}
        }
      },
      "Submission" => %{
        type: "object",
        properties: %{
          id: %{type: "integer", example: 111_222},
          assignment_id: %{type: "integer"},
          user_id: %{type: "integer"},
          workflow_state: %{
            type: "string",
            enum: ["submitted", "graded", "late", "missing", "unsubmitted"],
            example: "graded"
          },
          submitted_at: %{type: "string", format: "date-time", nullable: true},
          grade: %{type: "string", nullable: true, example: "95"},
          points: %{type: "number", nullable: true},
          secondary_points: %{type: "number", nullable: true},
          seconds_late: %{type: "integer", nullable: true},
          late_policy_status: %{type: "string", nullable: true},
          preview_url: %{type: "string", nullable: true},
          cachedRubricAttributes: %{type: "object", nullable: true},
          comment_attachments: %{
            type: "array",
            items: %{type: "object"},
            nullable: true
          }
        }
      },
      "StudentSubmissionsResponse" => %{
        type: "array",
        items: %{"$ref" => "#/components/schemas/SubmissionListItem"}
      },
      "SubmissionsResponse" => %{
        type: "array",
        items: %{"$ref" => "#/components/schemas/SubmissionListItem"}
      },
      "SubmissionResponse" => %{
        "$ref" => "#/components/schemas/Submission"
      }
    }
  end

  def openapi_operations do
    %{
      "/courses/{course_id}/students/{user_id}/submissions" => %{
        "get" => %{
          operationId: "listStudentSubmissions",
          summary: "List submissions for a student across all assignments in a course",
          description:
            "Returns all student submissions across assignments for the given course, only if the course is assigned to the authenticated service account.",
          tags: ["Submissions"],
          parameters: [
            %{
              name: "course_id",
              in: "path",
              required: true,
              description: "Canvas course ID",
              schema: %{type: "integer"}
            },
            %{
              name: "user_id",
              in: "path",
              required: true,
              description: "Canvas student (user) ID",
              schema: %{type: "integer"}
            }
          ],
          responses: %{
            "200" => %{
              description: "List of submissions by assignment",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/StudentSubmissionsResponse"}
                }
              }
            },
            "401" => %{"$ref" => "#/components/responses/Unauthorized"},
            "404" => %{"$ref" => "#/components/responses/NotFound"}
          }
        }
      },
      "/courses/{course_id}/assignments/{assignment_id}/submissions" => %{
        "get" => %{
          operationId: "listSubmissions",
          summary: "List submissions for an assignment",
          description:
            "Returns all student submissions for the given assignment, only if the parent course is assigned to the authenticated service account.",
          tags: ["Submissions"],
          parameters: [
            %{
              name: "course_id",
              in: "path",
              required: true,
              description: "Canvas course ID",
              schema: %{type: "integer"}
            },
            %{
              name: "assignment_id",
              in: "path",
              required: true,
              description: "Canvas assignment ID",
              schema: %{type: "integer"}
            }
          ],
          responses: %{
            "200" => %{
              description: "List of submissions",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/SubmissionsResponse"}
                }
              }
            },
            "401" => %{"$ref" => "#/components/responses/Unauthorized"},
            "404" => %{"$ref" => "#/components/responses/NotFound"}
          }
        }
      },
      "/courses/{course_id}/assignments/{assignment_id}/submissions/{id}" => %{
        "get" => %{
          operationId: "getSubmission",
          summary: "Get a submission",
          description:
            "Returns a single submission by ID, only if the parent course is assigned to the authenticated token.",
          tags: ["Submissions"],
          parameters: [
            %{
              name: "course_id",
              in: "path",
              required: true,
              description: "Canvas course ID",
              schema: %{type: "integer"}
            },
            %{
              name: "assignment_id",
              in: "path",
              required: true,
              description: "Canvas assignment ID",
              schema: %{type: "integer"}
            },
            %{
              name: "id",
              in: "path",
              required: true,
              description: "Canvas submission (student) ID",
              schema: %{type: "integer"}
            }
          ],
          responses: %{
            "200" => %{
              description: "Submission object",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/SubmissionResponse"}
                }
              }
            },
            "401" => %{"$ref" => "#/components/responses/Unauthorized"},
            "404" => %{"$ref" => "#/components/responses/NotFound"}
          }
        }
      }
    }
  end

  @doc "GET /api/v1/courses/:course_id/students/:user_id/submissions — list submissions by student"
  def index_by_student(conn, %{"course_id" => course_id, "user_id" => user_id}) do
    case ServiceAccount.list_student_submissions(
           conn.assigns.service_account_id,
           course_id,
           user_id
         ) do
      {:ok, submissions} ->
        formatted = Enum.map(submissions, &format_list_item/1)
        json(conn, formatted)

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{
          error: "not_found",
          message: "Student not found or course not assigned to this token"
        })

      {:error, _} ->
        conn
        |> put_status(500)
        |> json(%{error: "internal_error", message: "Failed to fetch submissions"})
    end
  end

  @doc "GET /api/v1/courses/:course_id/assignments/:assignment_id/submissions — list submissions"
  def index(conn, %{"course_id" => course_id, "assignment_id" => assignment_id}) do
    case ServiceAccount.list_assignment_submissions(
           conn.assigns.service_account_id,
           course_id,
           assignment_id
         ) do
      {:ok, submissions} ->
        formatted = Enum.map(submissions, &format_list_item/1)
        json(conn, formatted)

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{
          error: "not_found",
          message: "Assignment not found or course not assigned to this token"
        })

      {:error, _} ->
        conn
        |> put_status(500)
        |> json(%{error: "internal_error", message: "Failed to fetch submissions"})
    end
  end

  @doc "GET /api/v1/courses/:course_id/assignments/:assignment_id/submissions/:id — get a single submission"
  def show(conn, %{
        "course_id" => course_id,
        "assignment_id" => assignment_id,
        "id" => submission_id
      }) do
    case ServiceAccount.get_submission(
           conn.assigns.service_account_id,
           course_id,
           assignment_id,
           submission_id
         ) do
      {:ok, submission} ->
        json(conn, submission)

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{
          error: "not_found",
          message: "Submission not found or course not assigned to this token"
        })

      {:error, _} ->
        conn
        |> put_status(500)
        |> json(%{error: "internal_error", message: "Failed to fetch submission"})
    end
  end

  defp format_list_item(row) do
    posted_grade = row["posted_grade"]
    submitted_at = row["submitted_at"]
    due_at = row["due_at"]

    %{
      submission_id: row["submission_id"],
      assignment_id: row["assignment_id"],
      student_name: row["student_name"],
      student_id: row["user_id"],
      workflow_state: row["workflow_state"],
      score: score_string(posted_grade),
      posted_grade: posted_grade,
      submitted_at: submitted_at,
      submitted_at_formatted: relative_to_due(submitted_at, due_at)
    }
  end

  defp score_string(nil), do: nil
  defp score_string(posted_grade), do: posted_grade

  defp relative_to_due(submitted_at, due_at) when is_nil(submitted_at) or is_nil(due_at) do
    nil
  end

  defp relative_to_due(submitted_at, due_at) do
    with {:ok, submitted, _} <- DateTime.from_iso8601(submitted_at),
         {:ok, due, _} <- DateTime.from_iso8601(due_at) do
      diff_minutes = div(DateTime.diff(submitted, due), 60)

      cond do
        diff_minutes > 0 -> "#{format_early(diff_minutes)} before due"
        diff_minutes == 0 -> "right on time"
        diff_minutes > -1_440 -> "#{format_late(-diff_minutes)} after due"
        true -> "#{div(-diff_minutes, 1_440)} days late"
      end
    else
      _ -> nil
    end
  end

  defp format_early(minutes) when minutes < 60, do: "#{minutes} minutes"
  defp format_early(minutes) when minutes < 1_440, do: "#{div(minutes, 60)} hours"
  defp format_early(minutes) when minutes < 2_880, do: "1 day"
  defp format_early(minutes), do: "#{div(minutes, 1_440)} days"

  defp format_late(minutes) when minutes < 60, do: "#{minutes} minutes"
  defp format_late(minutes) when minutes < 1_440, do: "#{div(minutes, 60)} hours"
  defp format_late(minutes), do: "#{div(minutes, 1_440)} days"
end
