defmodule CanvasMcp.Data.User do
  require Logger
  alias CanvasMcp.Data.DbHelpers

  def schema do
    Zoi.object(%{
      id: Zoi.uuid(),
      email: Zoi.string(),
      is_admin: Zoi.boolean(),
      canvas_user_id: Zoi.nullish(Zoi.integer(coerce: true)),
      inserted_at: Zoi.datetime(),
      updated_at: Zoi.datetime()
    })
  end

  def find_or_create(email) do
    sql = """
    INSERT INTO users (email)
    VALUES ($(email))
    ON CONFLICT (email) DO UPDATE SET updated_at = NOW()
    RETURNING id, email, inserted_at, updated_at
    """

    case DbHelpers.run_sql(sql, %{"email" => email}) do
      {:error, reason} ->
        {:error, reason}

      [] ->
        {:error, :not_found}

      [%{"id" => user_id} | _] ->
        with :ok <- bootstrap_if_first(user_id) do
          get_by_id(user_id)
        end
    end
  end

  def get_by_id(user_id) do
    sql = """
    SELECT u.id, u.email, u.canvas_user_id, u.inserted_at, u.updated_at,
           (a.user_id IS NOT NULL) AS is_admin
    FROM users u
    LEFT JOIN admins a ON a.user_id = u.id
    WHERE u.id = $(user_id)
    """

    case DbHelpers.run_sql(sql, %{"user_id" => user_id}, schema()) do
      [user | _] -> {:ok, user}
      [] -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_by_email(email) do
    sql = """
    SELECT u.id, u.email, u.canvas_user_id, u.inserted_at, u.updated_at,
           (a.user_id IS NOT NULL) AS is_admin
    FROM users u
    LEFT JOIN admins a ON a.user_id = u.id
    WHERE u.email = $(email)
    """

    case DbHelpers.run_sql(sql, %{"email" => email}, schema()) do
      [user | _] -> {:ok, user}
      [] -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def has_canvas_token?(user_id) do
    sql = """
    SELECT canvas_token IS NOT NULL AS has_token
    FROM users
    WHERE id = $(user_id)
    """

    case DbHelpers.run_sql(sql, %{"user_id" => user_id}) do
      [%{"has_token" => result} | _] -> result
      _ -> false
    end
  end

  def get_canvas_token_for_user(user_id) do
    sql = """
    SELECT canvas_token
    FROM users
    WHERE id = $(user_id)
    """

    case DbHelpers.run_sql(sql, %{"user_id" => user_id}) do
      [%{"canvas_token" => token} | _] -> {:ok, token}
      [] -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def set_canvas_token(user_id, token) do
    sql = """
    UPDATE users
    SET canvas_token = $(token), updated_at = NOW()
    WHERE id = $(user_id)
    """

    case DbHelpers.run_sql(sql, %{"user_id" => user_id, "token" => token}) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  def set_canvas_user_id(user_id, canvas_user_id) do
    sql = """
    UPDATE users
    SET canvas_user_id = $(canvas_user_id), updated_at = NOW()
    WHERE id = $(user_id)
    """

    case DbHelpers.run_sql(sql, %{"user_id" => user_id, "canvas_user_id" => canvas_user_id}) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  def get_canvas_user_id(user_id) do
    sql = "SELECT canvas_user_id FROM users WHERE id = $(user_id)"

    case DbHelpers.run_sql(sql, %{"user_id" => user_id}) do
      [%{"canvas_user_id" => id} | _] -> {:ok, id}
      [] -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def grant_admin(user_id, granted_by \\ nil) do
    sql = """
    INSERT INTO admins (user_id, granted_by)
    VALUES ($(user_id), $(granted_by))
    ON CONFLICT (user_id) DO NOTHING
    """

    case DbHelpers.run_sql(sql, %{"user_id" => user_id, "granted_by" => granted_by}) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  # Bootstraps the first admin: if no admins exist yet, grants admin to user_id.
  defp bootstrap_if_first(user_id) do
    sql = "SELECT COUNT(*) AS count FROM admins"

    case DbHelpers.run_sql(sql, %{}) do
      [%{"count" => 0}] ->
        Logger.info("No admins found — granting admin to first user user_id=#{user_id}")
        grant_admin(user_id, nil)

      _ ->
        :ok
    end
  end
end
