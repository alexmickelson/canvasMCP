defmodule CanvasMcp.Canvas.User do
  require Logger
  alias CanvasMcp.Data.DbHelpers
  alias CanvasMcp.Canvas.Client

  def schema do
    Zoi.object(%{
      id: Zoi.integer(coerce: true),
      name: Zoi.string(),
      sortable_name: Zoi.string(),
      short_name: Zoi.string(),
      login_id: Zoi.optional(Zoi.string()),
      sis_user_id: Zoi.nullish(Zoi.string()),
      email: Zoi.optional(Zoi.nullish(Zoi.string())),
      avatar_url: Zoi.optional(Zoi.nullish(Zoi.string())),
      time_zone: Zoi.optional(Zoi.nullish(Zoi.string())),
      locale: Zoi.optional(Zoi.nullish(Zoi.string())),
      pronouns: Zoi.optional(Zoi.nullish(Zoi.string())),
      bio: Zoi.optional(Zoi.nullish(Zoi.string()))
    })
  end

  def fetch_self(token) do
    with {:ok, raw} <- Client.get_one("/users/self", token) do
      case Zoi.parse(schema(), raw, coerce: true) do
        {:ok, user} -> {:ok, user}
        {:error, errors} -> {:error, {:parse_error, errors}}
      end
    end
  end

  def fetch_self_with_token(token) do
    with {:ok, raw} <- Client.get_one("/users/self", token) do
      case Zoi.parse(schema(), raw, coerce: true) do
        {:ok, user} -> {:ok, user}
        {:error, errors} -> {:error, {:parse_error, errors}}
      end
    end
  end

  def fetch_and_store_with_token(token) do
    with {:ok, user} <- fetch_self_with_token(token) do
      case store(user) do
        :ok -> {:ok, user}
        err -> err
      end
    end
  end

  def get_or_fetch(canvas_user_id, token) do
    case get_by_id(canvas_user_id) do
      {:ok, user} ->
        {:ok, user}

      {:error, :not_found} ->
        with {:ok, raw} <- Client.get_one("/users/#{canvas_user_id}", token) do
          case Zoi.parse(schema(), raw, coerce: true) do
            {:ok, user} ->
              case store(user) do
                :ok -> {:ok, user}
                err -> err
              end

            {:error, errors} ->
              Logger.error("Failed to parse user #{canvas_user_id}: #{inspect(errors)}")
              {:error, {:parse_error, errors}}
          end
        end

      err ->
        err
    end
  end

  def fetch_self_and_store(token) do
    with {:ok, user} <- fetch_self(token) do
      case store(user) do
        :ok -> {:ok, user}
        err -> err
      end
    end
  end

  def store(user) do
    sql = """
    INSERT INTO canvas_users (id, login_id, canvas_object, updated_at)
    VALUES ($(id), $(login_id), $(canvas_object)::jsonb, NOW())
    ON CONFLICT (id) DO UPDATE SET
      login_id      = EXCLUDED.login_id,
      canvas_object = EXCLUDED.canvas_object,
      updated_at    = EXCLUDED.updated_at
    """

    params = %{
      "id" => user.id,
      "login_id" => Map.get(user, :login_id),
      "canvas_object" => user
    }

    case DbHelpers.run_sql(sql, params) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  def get_by_id(canvas_user_id) do
    sql = "SELECT canvas_object FROM canvas_users WHERE id = $(id)"

    case DbHelpers.run_sql(sql, %{"id" => canvas_user_id}) do
      {:error, reason} -> {:error, reason}
      [] -> {:error, :not_found}
      [row | _] -> parse_canvas_object(row)
    end
  end

  def get_by_login_id(login_id) do
    sql = "SELECT canvas_object FROM canvas_users WHERE login_id = $(login_id)"

    case DbHelpers.run_sql(sql, %{"login_id" => login_id}) do
      {:error, reason} -> {:error, reason}
      [] -> {:error, :not_found}
      [row | _] -> parse_canvas_object(row)
    end
  end

  def list_all do
    sql = "SELECT canvas_object FROM canvas_users ORDER BY updated_at DESC"

    case DbHelpers.run_sql(sql, %{}) do
      {:error, reason} -> {:error, reason}
      rows -> {:ok, parse_rows(rows)}
    end
  end

  def delete(canvas_user_id) do
    sql = "DELETE FROM canvas_users WHERE id = $(id)"

    case DbHelpers.run_sql(sql, %{"id" => canvas_user_id}) do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  defp parse_rows(rows) do
    Enum.flat_map(rows, fn row ->
      case parse_canvas_object(row) do
        {:ok, user} -> [user]
        _ -> []
      end
    end)
  end

  defp parse_canvas_object(%{"canvas_object" => obj}) do
    case Zoi.parse(schema(), obj, coerce: true) do
      {:ok, user} -> {:ok, user}
      {:error, errors} -> {:error, {:parse_error, errors}}
    end
  end
end
