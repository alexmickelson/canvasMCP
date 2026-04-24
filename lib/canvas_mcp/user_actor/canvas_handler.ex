defmodule CanvasMcp.UserActor.CanvasHandler do
  require Logger

  alias CanvasMcp.Canvas.Course
  alias CanvasMcp.UserActor.Helpers

  def handle({:get_canvas_courses, _}, %{canvas_token: nil} = state) do
    broadcast(state.user_id, {:canvas, :error, :no_canvas_token})
    {:noreply, state}
  end

  def handle({:get_canvas_courses, invalidate_cache}, %{canvas_token: token} = state) do
    case Course.get_all_courses(token, invalidate_cache) do
      {:ok, courses} ->
        broadcast(state.user_id, {:canvas, :courses_refreshed, courses})

      {:error, reason} ->
        Logger.error(
          "UserActor courses fetch failed for user_id=#{state.user_id}: #{inspect(reason)}"
        )

        broadcast(state.user_id, {:canvas, :error, reason})
    end

    {:noreply, state}
  end

  defp broadcast(user_id, message), do: Helpers.broadcast(user_id, message)
end
