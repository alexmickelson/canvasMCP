defmodule CanvasMcpWeb.Api.Courses.CoursesController do
  use CanvasMcpWeb, :controller
  alias CanvasMcp.Data.ServiceAccount

  # ---------------------------------------------------------------------------
  # OpenAPI metadata — consumed by CanvasMcpWeb.Api.OpenApi to build the spec.
  # Keep schemas and operations here so they stay in sync with the implementation.
  # ---------------------------------------------------------------------------

  def openapi_schemas do
    %{
      "CourseTerm" => %{
        type: "object",
        properties: %{
          id: %{type: "integer"},
          name: %{type: "string", example: "Spring 2026"},
          start_at: %{type: "string", format: "date-time", nullable: true},
          end_at: %{type: "string", format: "date-time", nullable: true}
        }
      },
      "Course" => %{
        type: "object",
        properties: %{
          id: %{type: "integer", example: 1_210_936},
          name: %{type: "string", example: "Web Intro"},
          course_code: %{type: "string", example: "202610 CS-1810-001"},
          workflow_state: %{
            type: "string",
            enum: ["available", "unpublished", "completed", "deleted"]
          },
          enrollment_term_id: %{type: "integer"},
          hide_final_grades: %{type: "boolean"},
          term: %{"$ref" => "#/components/schemas/CourseTerm"}
        }
      },
      "CoursesResponse" => %{
        type: "object",
        required: ["data"],
        properties: %{
          data: %{type: "array", items: %{"$ref" => "#/components/schemas/Course"}}
        }
      },
      "CourseResponse" => %{
        type: "object",
        required: ["data"],
        properties: %{
          data: %{"$ref" => "#/components/schemas/Course"}
        }
      }
    }
  end

  def openapi_operations do
    %{
      "/courses" => %{
        "get" => %{
          operationId: "listCourses",
          summary: "List assigned courses",
          description:
            "Returns all Canvas courses assigned to the authenticated service account token.",
          tags: ["Courses"],
          responses: %{
            "200" => %{
              description: "List of assigned courses",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/CoursesResponse"}
                }
              }
            },
            "401" => %{"$ref" => "#/components/responses/Unauthorized"}
          }
        }
      },
      "/courses/{id}" => %{
        "get" => %{
          operationId: "getCourse",
          summary: "Get a course",
          description:
            "Returns a single Canvas course by ID, only if assigned to the authenticated token.",
          tags: ["Courses"],
          parameters: [
            %{
              name: "id",
              in: "path",
              required: true,
              description: "Canvas course ID",
              schema: %{type: "integer"}
            }
          ],
          responses: %{
            "200" => %{
              description: "Course object",
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/CourseResponse"}
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

  # ---------------------------------------------------------------------------
  # Actions
  # ---------------------------------------------------------------------------

  @doc "GET /api/v1/courses — list all courses assigned to this service account"
  def index(conn, _params) do
    case ServiceAccount.list_assigned_courses(conn.assigns.service_account_id) do
      {:ok, courses} ->
        json(conn, %{data: courses})

      {:error, _} ->
        conn
        |> put_status(500)
        |> json(%{error: "internal_error", message: "Failed to fetch courses"})
    end
  end

  @doc "GET /api/v1/courses/:id — get a single course assigned to this service account"
  def show(conn, %{"id" => course_id}) do
    case ServiceAccount.get_assigned_course(conn.assigns.service_account_id, course_id) do
      {:ok, course} ->
        json(conn, %{data: course})

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Course not found or not assigned to this token"})

      {:error, _} ->
        conn
        |> put_status(500)
        |> json(%{error: "internal_error", message: "Failed to fetch course"})
    end
  end
end
