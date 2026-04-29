defmodule CanvasMcpWeb.Api.OpenApi do
  @moduledoc """
  Assembles the OpenAPI 3.1 spec from metadata declared in each API controller.

  ## Adding a new endpoint

  1. Implement `openapi_schemas/0` and `openapi_operations/0` in your controller.
  2. Add the controller module to `@controllers` below.

  `openapi_schemas/0` returns `%{"SchemaName" => schema_map}`.
  `openapi_operations/0` returns `%{"/path" => %{"get" | "post" | ... => operation_map}}`.
  Operations may reference shared response components via `$ref`.
  """

  alias CanvasMcpWeb.Api.Courses.CoursesController

  # Register every controller that contributes to the spec here.
  @controllers [
    CoursesController
  ]

  # Shared response components referenced by operations via "$ref".
  @shared_responses %{
    "Unauthorized" => %{
      description: "Unauthorized — missing or invalid API token",
      content: %{
        "application/json" => %{schema: %{"$ref" => "#/components/schemas/Error"}}
      }
    },
    "NotFound" => %{
      description: "Resource not found or not accessible to this token",
      content: %{
        "application/json" => %{schema: %{"$ref" => "#/components/schemas/Error"}}
      }
    },
    "InternalError" => %{
      description: "Unexpected server error",
      content: %{
        "application/json" => %{schema: %{"$ref" => "#/components/schemas/Error"}}
      }
    }
  }

  @shared_schemas %{
    "Error" => %{
      type: "object",
      required: ["error", "message"],
      properties: %{
        error: %{type: "string", example: "not_found"},
        message: %{type: "string", example: "Resource not found"}
      }
    }
  }

  def build(base_url) do
    {all_schemas, all_paths} =
      Enum.reduce(@controllers, {%{}, %{}}, fn mod, {schemas, paths} ->
        {
          Map.merge(schemas, mod.openapi_schemas()),
          Map.merge(paths, mod.openapi_operations())
        }
      end)

    %{
      openapi: "3.1.0",
      info: %{
        title: "CanvasMCP API",
        version: "1.0.0",
        description: """
        REST API for accessing Canvas LMS data cached by CanvasMCP.
        Authenticate with a service account token via `Authorization: Bearer <token>`.
        Each token only exposes the courses explicitly assigned to it in the dashboard.
        """
      },
      servers: [%{url: "#{base_url}/api/v1", description: "CanvasMCP API v1"}],
      security: [%{BearerAuth: []}],
      components: %{
        securitySchemes: %{
          BearerAuth: %{
            type: "http",
            scheme: "bearer",
            bearerFormat: "ServiceAccountToken",
            description: "Service account token generated in the CanvasMCP dashboard."
          }
        },
        schemas: Map.merge(@shared_schemas, all_schemas),
        responses: @shared_responses
      },
      paths: all_paths
    }
  end
end
