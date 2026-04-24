defmodule CanvasMcp.UserActor do
  use GenServer
  require Logger

  alias CanvasMcp.Data.User, as: DataUser
  alias CanvasMcp.Canvas.User, as: CanvasUser
  alias CanvasMcp.UserActor.CanvasHandler
  alias CanvasMcp.UserActor.ProfileHandler
  alias CanvasMcp.UserActor.Helpers

  def ensure_started(user_id) do
    case DynamicSupervisor.start_child(
           CanvasMcp.UserActorSupervisor,
           {__MODULE__, user_id}
         ) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_data(user_id) do
    GenServer.cast(via(user_id), :get_data)
  end

  def get_canvas_courses(user_id, invalidate_cache \\ false) do
    GenServer.cast(via(user_id), {:canvas, {:get_canvas_courses, invalidate_cache}})
  end

  def update_canvas_token(user_id, token) do
    GenServer.cast(via(user_id), {:profile, {:update_canvas_token, token}})
  end

  def user_channel(user_id), do: Helpers.user_channel(user_id)

  def subscribe_to_user(user_id) do
    Phoenix.PubSub.subscribe(CanvasMcp.PubSub, user_channel(user_id))
  end

  def start_link(user_id) do
    GenServer.start_link(__MODULE__, user_id, name: via(user_id))
  end

  @impl true
  def init(user_id) do
    CanvasMcp.UserActorsPG.join()

    state =
      case DataUser.get_by_id(user_id) do
        {:ok, user} ->
          canvas_token =
            case DataUser.get_canvas_token_for_user(user_id) do
              {:ok, token} -> token
              _ -> nil
            end

          %{
            user_id: user_id,
            user: user,
            canvas_token: canvas_token,
            canvas_user: load_canvas_user(user)
          }

        {:error, reason} ->
          Logger.error("UserActor init failed for user_id=#{user_id}: #{inspect(reason)}")
          %{user_id: user_id, user: nil, canvas_token: nil, canvas_user: nil}
      end

    {:ok, state}
  end

  @impl true
  def handle_cast(:get_data, state) do
    broadcast(state.user_id, {:canvas, :data, state})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:canvas, msg}, state) do
    CanvasHandler.handle(msg, state)
  end

  @impl true
  def handle_cast({:profile, msg}, state) do
    ProfileHandler.handle(msg, state)
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  defp broadcast(user_id, message), do: Helpers.broadcast(user_id, message)

  defp via(user_id) do
    {:via, Registry, {CanvasMcp.UserRegistry, user_id}}
  end

  defp load_canvas_user(%{canvas_user_id: nil}), do: nil

  defp load_canvas_user(%{canvas_user_id: canvas_user_id}) do
    case CanvasUser.get_by_id(canvas_user_id) do
      {:ok, cu} -> cu
      _ -> nil
    end
  end
end
