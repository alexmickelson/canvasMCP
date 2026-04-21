defmodule CanvasMcp.UserServersPG do
  @pg_scope CanvasMcp.UserPG
  @pg_group :user_servers

  def join do
    :pg.join(@pg_scope, @pg_group, self())
  end

  def active_count do
    :pg.get_members(@pg_scope, @pg_group) |> length()
  end

  def active_user_ids do
    @pg_scope
    |> :pg.get_members(@pg_group)
    |> Enum.flat_map(&Registry.keys(CanvasMcp.UserRegistry, &1))
  end
end
