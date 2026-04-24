defmodule CanvasMcp.UserActor.ProfileHandler do
  require Logger

  alias CanvasMcp.Data.User, as: DataUser
  alias CanvasMcp.Canvas.User, as: CanvasUser
  alias CanvasMcp.UserActor.Helpers

  def handle({:update_canvas_token, token}, state) do
    case DataUser.set_canvas_token(state.user_id, token) do
      :ok ->
        canvas_user =
          if token do
            case CanvasUser.fetch_and_store_with_token(token) do
              {:ok, cu} ->
                DataUser.set_canvas_user_id(state.user_id, cu.id)
                cu

              _ ->
                state.canvas_user
            end
          else
            DataUser.set_canvas_user_id(state.user_id, nil)
            nil
          end

        user =
          case DataUser.get_by_id(state.user_id) do
            {:ok, u} -> u
            _ -> state.user
          end

        new_state = %{state | canvas_token: token, canvas_user: canvas_user, user: user}
        broadcast(state.user_id, {:canvas, :token_updated, new_state})
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error(
          "UserActor update_canvas_token failed for user_id=#{state.user_id}: #{inspect(reason)}"
        )

        broadcast(state.user_id, {:canvas, :error, reason})
        {:noreply, state}
    end
  end

  defp broadcast(user_id, message), do: Helpers.broadcast(user_id, message)
end
