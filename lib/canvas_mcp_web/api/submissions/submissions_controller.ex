defmodule CanvasMcpWeb.Api.Submissions.SubmissionsController do
  use CanvasMcpWeb, :controller
  alias CanvasMcp.Data.ServiceAccount

  # ---------------------------------------------------------------------------
  # OpenAPI metadata — consumed by CanvasMcpWeb.Api.OpenApi to build the spec.
  # ---------------------------------------------------------------------------

  def openapi_schemas do
    %{
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
      "SubmissionsResponse" => %{
        type: "object",
        required: ["data"],
        properties: %{
          data: %{type: "array", items: %{"$ref" => "#/components/schemas/Submission"}}
        }
      },
      "SubmissionResponse" => %{
        type: "object",
        required: ["data"],
        properties: %{
          data: %{"$ref" => "#/components/schemas/Submission"}
        }
      }
    }
  end

  def openapi_operations do
    %{
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

  @doc "GET /api/v1/courses/:course_id/assignments/:assignment_id/submissions — list submissions"
  def index(conn, %{"course_id" => course_id, "assignment_id" => assignment_id}) do
    case ServiceAccount.list_assignment_submissions(
           conn.assigns.service_account_id,
           course_id,
           assignment_id
         ) do
      {:ok, submissions} ->
        json(conn, %{data: submissions})

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Assignment not found or course not assigned to this token"})

      {:error, _} ->
        conn
        |> put_status(500)
        |> json(%{error: "internal_error", message: "Failed to fetch submissions"})
    end
  end

  @doc "GET /api/v1/courses/:course_id/assignments/:assignment_id/submissions/:id — get a single submission"
  def show(conn, %{"course_id" => course_id, "assignment_id" => assignment_id, "id" => submission_id}) do
    case ServiceAccount.get_submission(
           conn.assigns.service_account_id,
           course_id,
           assignment_id,
           submission_id
         ) do
      {:ok, submission} ->
        json(conn, %{data: submission})

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Submission not found or course not assigned to this token"})

      {:error, _} ->
        conn
        |> put_status(500)
        |> json(%{error: "internal_error", message: "Failed to fetch submission"})
    end
  end
end
