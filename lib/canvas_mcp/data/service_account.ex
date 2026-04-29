defmodule CanvasMcp.Data.ServiceAccount do
  alias CanvasMcp.Data.DbHelpers

  def create(user_id, name) do
    raw_token = generate_token()
    token_hash = hash_token(raw_token)
    token_prefix = String.slice(raw_token, 0, 8)

    sql = """
    INSERT INTO service_accounts (user_id, name, token_hash, token_prefix)
    VALUES ($(user_id), $(name), $(token_hash), $(token_prefix))
    RETURNING id, name, token_prefix, inserted_at
    """

    params = %{
      "user_id" => user_id,
      "name" => name,
      "token_hash" => token_hash,
      "token_prefix" => token_prefix
    }

    case DbHelpers.run_sql(sql, params) do
      {:error, reason} -> {:error, reason}
      [row | _] -> {:ok, row, raw_token}
    end
  end

  def get_by_id(id, user_id) do
    sql = """
    SELECT id, name, token_prefix, inserted_at
    FROM service_accounts
    WHERE id = $(id) AND user_id = $(user_id)
    """

    case DbHelpers.run_sql(sql, %{"id" => id, "user_id" => user_id}) do
      {:error, reason} -> {:error, reason}
      [] -> {:error, :not_found}
      [row | _] -> {:ok, row}
    end
  end

  def list_for_user(user_id) do
    sql = """
    SELECT id, name, token_prefix, inserted_at
    FROM service_accounts
    WHERE user_id = $(user_id)
    ORDER BY inserted_at DESC
    """

    case DbHelpers.run_sql(sql, %{"user_id" => user_id}) do
      {:error, reason} -> {:error, reason}
      rows -> {:ok, rows}
    end
  end

  def revoke(id, user_id) do
    sql = """
    DELETE FROM service_accounts
    WHERE id = $(id) AND user_id = $(user_id)
    """

    case DbHelpers.run_sql(sql, %{"id" => id, "user_id" => user_id}) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  def list_courses_with_assignment(service_account_id, canvas_user_id) do
    sql = """
    SELECT
      cc.id,
      cc.canvas_object->>'name'              AS name,
      cc.canvas_object->>'course_code'       AS course_code,
      cc.canvas_object->'term'->>'name'      AS term_name,
      cc.canvas_object->'term'->>'end_at'    AS term_end_at,
      cc.canvas_object->>'workflow_state'    AS workflow_state,
      (sac.service_account_id IS NOT NULL)   AS assigned
    FROM canvas_courses cc
    LEFT JOIN service_account_courses sac
      ON sac.course_id = cc.id
      AND sac.service_account_id = $(service_account_id)
    WHERE cc.canvas_user_id = $(canvas_user_id)
    ORDER BY cc.canvas_object->'term'->>'end_at' DESC NULLS LAST, cc.id
    """

    case DbHelpers.run_sql(sql, %{
           "service_account_id" => service_account_id,
           "canvas_user_id" => canvas_user_id
         }) do
      {:error, reason} -> {:error, reason}
      rows -> {:ok, rows}
    end
  end

  def assign_course(service_account_id, course_id, user_id) do
    sql = """
    INSERT INTO service_account_courses (service_account_id, course_id)
    SELECT $(service_account_id)::uuid, $(course_id)::bigint
    WHERE EXISTS (
      SELECT 1 FROM service_accounts
      WHERE id = $(service_account_id) AND user_id = $(user_id)
    )
    ON CONFLICT DO NOTHING
    """

    case DbHelpers.run_sql(sql, %{
           "service_account_id" => service_account_id,
           "course_id" => to_integer(course_id),
           "user_id" => user_id
         }) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  def unassign_course(service_account_id, course_id, user_id) do
    sql = """
    DELETE FROM service_account_courses
    WHERE service_account_id = $(service_account_id)
      AND course_id = $(course_id)
      AND EXISTS (
        SELECT 1 FROM service_accounts
        WHERE id = $(service_account_id) AND user_id = $(user_id)
      )
    """

    case DbHelpers.run_sql(sql, %{
           "service_account_id" => service_account_id,
           "course_id" => to_integer(course_id),
           "user_id" => user_id
         }) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  def get_by_token(raw_token) do
    token_hash = hash_token(raw_token)

    sql = """
    SELECT sa.id, sa.user_id, sa.name
    FROM service_accounts sa
    WHERE sa.token_hash = $(token_hash)
    """

    case DbHelpers.run_sql(sql, %{"token_hash" => token_hash}) do
      {:error, reason} -> {:error, reason}
      [] -> {:error, :not_found}
      [row | _] -> {:ok, row}
    end
  end

  @doc """
  Returns all courses assigned to this service account with their full canvas_object.
  """
  def list_assigned_courses(service_account_id) do
    sql = """
    SELECT cc.canvas_object
    FROM canvas_courses cc
    INNER JOIN service_account_courses sac ON sac.course_id = cc.id
    WHERE sac.service_account_id = $(service_account_id)
    ORDER BY cc.canvas_object->'term'->>'end_at' DESC NULLS LAST, cc.id
    """

    case DbHelpers.run_sql(sql, %{"service_account_id" => service_account_id}) do
      {:error, reason} -> {:error, reason}
      rows -> {:ok, Enum.map(rows, & &1["canvas_object"])}
    end
  end

  @doc """
  Returns a single course's canvas_object only if it is assigned to the service account.
  """
  def get_assigned_course(service_account_id, course_id) do
    sql = """
    SELECT cc.canvas_object
    FROM canvas_courses cc
    INNER JOIN service_account_courses sac ON sac.course_id = cc.id
    WHERE sac.service_account_id = $(service_account_id)
      AND cc.id = $(course_id)
    """

    case DbHelpers.run_sql(sql, %{
           "service_account_id" => service_account_id,
           "course_id" => to_integer(course_id)
         }) do
      {:error, reason} -> {:error, reason}
      [] -> {:error, :not_found}
      [row | _] -> {:ok, row["canvas_object"]}
    end
  end

  defp to_integer(v) when is_integer(v), do: v
  defp to_integer(v) when is_binary(v), do: String.to_integer(v)

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
  end

  defp hash_token(raw_token) do
    :crypto.hash(:sha256, raw_token) |> Base.encode16(case: :lower)
  end
end
