defmodule CanvasMcp.Data.AuditLog do
  require Logger
  alias CanvasMcp.Data.DbHelpers

  @topic "audit_log"
  @valid_events ~w(login_success login_failure logout session_refresh)

  @type event :: :login_success | :login_failure | :logout | :session_refresh

  def topic, do: @topic

  def row_schema do
    Zoi.object(%{
      id: Zoi.uuid(),
      user_id: Zoi.optional(Zoi.nullish(Zoi.uuid())),
      event: Zoi.enum(@valid_events),
      remote_ip: Zoi.optional(Zoi.nullish(Zoi.string())),
      data: Zoi.optional(Zoi.nullish(Zoi.map())),
      inserted_at: Zoi.datetime()
    })
  end

  @spec record(event(), String.t() | nil, String.t() | nil, map()) :: :ok
  def record(event, user_id, remote_ip, data \\ %{}) do
    sql = """
    INSERT INTO audit_log (user_id, event, remote_ip, data)
    VALUES ($(user_id), $(event), $(remote_ip), $(data)::jsonb)
    RETURNING id, user_id, event, remote_ip, data, inserted_at
    """

    params = %{
      "user_id" => user_id,
      "event" => Atom.to_string(event),
      "remote_ip" => remote_ip,
      "data" => Jason.encode!(data)
    }

    case DbHelpers.run_sql(sql, params, row_schema()) do
      {:error, reason} ->
        Logger.error("Failed to write audit log event=#{event} reason=#{inspect(reason)}")

      [row | _] ->
        Phoenix.PubSub.broadcast(CanvasMcp.PubSub, @topic, {:new_audit_entry, row})
        :ok
    end
  end

  @spec list(keyword()) :: list() | {:error, atom()}
  def list(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    order = if Keyword.get(opts, :order, :desc) == :asc, do: "ASC", else: "DESC"

    sql = """
    SELECT al.id, al.user_id, al.event, al.remote_ip, al.data, al.inserted_at,
           u.email AS user_email
    FROM audit_log al
    LEFT JOIN users u ON u.id = al.user_id
    ORDER BY al.inserted_at #{order}
    LIMIT $(limit)
    OFFSET $(offset)
    """

    schema =
      Zoi.object(%{
        id: Zoi.uuid(),
        user_id: Zoi.optional(Zoi.nullish(Zoi.uuid())),
        user_email: Zoi.optional(Zoi.nullish(Zoi.string())),
        event: Zoi.enum(@valid_events),
        remote_ip: Zoi.optional(Zoi.nullish(Zoi.string())),
        data: Zoi.optional(Zoi.nullish(Zoi.map())),
        inserted_at: Zoi.datetime()
      })

    DbHelpers.run_sql(sql, %{"limit" => limit, "offset" => offset}, schema)
  end
end
