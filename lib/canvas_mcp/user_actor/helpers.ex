defmodule CanvasMcp.UserActor.Helpers do
  def user_channel(user_id), do: "user:#{user_id}"
  def error_channel(user_id), do: "user_errors:#{user_id}"

  def broadcast(user_id, message) do
    Phoenix.PubSub.broadcast(CanvasMcp.PubSub, user_channel(user_id), message)
  end

  def broadcast_error(user_id, message) when is_binary(message) do
    Phoenix.PubSub.broadcast(CanvasMcp.PubSub, error_channel(user_id), {:user_error, message})
  end
end
