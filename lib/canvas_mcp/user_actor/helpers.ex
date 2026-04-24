defmodule CanvasMcp.UserActor.Helpers do
  def user_channel(user_id), do: "user:#{user_id}"

  def broadcast(user_id, message) do
    Phoenix.PubSub.broadcast(CanvasMcp.PubSub, user_channel(user_id), message)
  end
end
