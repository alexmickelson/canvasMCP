defmodule CanvasMcpWeb.Api.Assignments.AssignmentsController do
  use CanvasMcpWeb, :controller
  alias CanvasMcp.Data.ServiceAccount

  # ---------------------------------------------------------------------------
  # OpenAPI metadata — consumed by CanvasMcpWeb.Api.OpenApi to build the spec.
  # ---------------------------------------------------------------------------

  def openapi_schemas do
    %{
      "Assignment" => %{
        type: "object",
        properties: %{
          id: %{type: "integer", example: 987_654},
          name: %{type: "string", example: "Homework 1"},
          description: %{type: "string", nullable: true, example: "Complete exercises 1–5."},
          points_possible: %{type: "number", nullable: true},
          assignment_group_id: %{type: "integer", nullable: true},
          submitted_at: %{type: "string", format: "date-time", nullable: true},
          due_at: %{type: "string", format: "date-time", nullable: true},
          lock_at: %{type: "string", format: "date-time", nullable: true},
          unlock_at: %{type: "string", format: "date-time", nullable: true},
          lock_explanation: %{type: "string", nullable: true},
          grading_type: %{type: "string", nullable: true, example: "points"},
          submission_types: %{
            type: "array",
            items: %{type: "string"},
            nullable: true,
            example: ["online_text_entry"]
          },
          peer_reviews: %{type: "boolean"},
          publish_final_grade: %{type: "boolean"},
          omit_from_final_grade: %{type: "boolean"},
          position: %{type: "integer"},
          owned_by_course: %{type: "boolean"},
          version: %{type: "integer"},
          workflow_state: %{type: "string", example: "published"}
        }
      },
      "AssignmentsResponse" => %{
        type: "object",
        required: ["data"],
        properties: %{
          data: %{type: "array", items: %{"$ref" => "#/components/schemas/Assignment"}}
        }
      },
      "AssignmentResponse" => %{
        type: "object",
        required: ["data"],
        properties: %{
          data: %{"$ref" => "#/components/schemas/Assignment"}
        }
      }
    }
  end

  def openapi_operations do
    %{
      "/courses/{course_id}/assignments" => %{
        "get" => %{
          operationId: "listAssignments",
          summary: "List assignments for a course",
          description:
            "Returns all assignments for the given course, only if the course is assigned to the authenticated service account.",
          tags: ["Assignments"],
          parameters: [
            %{
              name: "course_id",
              in: "path",
              required: true,
              description: "Canvas course ID",
              schema: %{type: "integer"}
            }
          ],
          responses: %{
            "200" => %{
              description: "List of assignments",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/AssignmentsResponse"}
                }
              }
            },
            "401" => %{"$ref" => "#/components/responses/Unauthorized"},
            "404" => %{"$ref" => "#/components/responses/NotFound"}
          }
        }
      },
      "/courses/{course_id}/assignments/{id}" => %{
        "get" => %{
          operationId: "getAssignment",
          summary: "Get an assignment",
          description:
            "Returns a single assignment by ID, only if the parent course is assigned to the authenticated token.",
          tags: ["Assignments"],
          parameters: [
            %{
              name: "course_id",
              in: "path",
              required: true,
              description: "Canvas course ID",
              schema: %{type: "integer"}
            },
            %{
              name: "id",
              in: "path",
              required: true,
              description: "Canvas assignment ID",
              schema: %{type: "integer"}
            }
          ],
          responses: %{
            "200" => %{
              description: "Assignment object",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/AssignmentResponse"}
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

  @doc "GET /api/v1/courses/:course_id/assignments — list assignments for a course"
  def index(conn, %{"course_id" => course_id}) do
    case ServiceAccount.list_course_assignments(conn.assigns.service_account_id, course_id) do
      {:ok, assignments} ->
        json(conn, %{data: assignments})

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Course not found or not assigned to this token"})

      {:error, _} ->
        conn
        |> put_status(500)
        |> json(%{error: "internal_error", message: "Failed to fetch assignments"})
    end
  end

  @doc "GET /api/v1/courses/:course_id/assignments/:id — get a single assignment"
  def show(conn, %{"course_id" => course_id, "id" => assignment_id}) do
    case ServiceAccount.get_assignment(
           conn.assigns.service_account_id,
           course_id,
           assignment_id
         ) do
      {:ok, assignment} ->
        json(conn, %{data: assignment})

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
        |> json(%{error: "internal_error", message: "Failed to fetch assignment"})
    end
  end
end
