defmodule CanvasMcp.UserServer do
  use GenServer
  require Logger

  alias CanvasMcp.Data.User, as: DataUser
  alias CanvasMcp.Canvas.User, as: CanvasUser
  alias CanvasMcp.Canvas.Course

  def ensure_started(user_id) do
    case DynamicSupervisor.start_child(
           CanvasMcp.UserServerSupervisor,
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
    GenServer.cast(via(user_id), {:get_canvas_courses, invalidate_cache})
  end

  def update_canvas_token(user_id, token) do
    GenServer.cast(via(user_id), {:update_canvas_token, token})
  end

  def user_channel(user_id), do: "user:#{user_id}"

  def subscribe_to_user(user_id) do
    Phoenix.PubSub.subscribe(CanvasMcp.PubSub, user_channel(user_id))
  end

  def start_link(user_id) do
    GenServer.start_link(__MODULE__, user_id, name: via(user_id))
  end

  @impl true
  def init(user_id) do
    CanvasMcp.UserServersPG.join()

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
          Logger.error("UserServer init failed for user_id=#{user_id}: #{inspect(reason)}")
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
  def handle_cast({:get_canvas_courses, _}, %{canvas_token: nil} = state) do
    broadcast(state.user_id, {:canvas, :error, :no_canvas_token})
    {:noreply, state}
  end

  def handle_cast({:get_canvas_courses, invalidate_cache}, %{canvas_token: token} = state) do
    case Course.get_all_courses(token, invalidate_cache) do
      {:ok, courses} ->
        broadcast(state.user_id, {:canvas, :courses_refreshed, courses})

      {:error, reason} ->
        Logger.error(
          "UserServer courses fetch failed for user_id=#{state.user_id}: #{inspect(reason)}"
        )

        broadcast(state.user_id, {:canvas, :error, reason})
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:update_canvas_token, token}, state) do
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
          "UserServer update_canvas_token failed for user_id=#{state.user_id}: #{inspect(reason)}"
        )

        broadcast(state.user_id, {:canvas, :error, reason})
        {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  defp broadcast(user_id, message) do
    Phoenix.PubSub.broadcast(CanvasMcp.PubSub, user_channel(user_id), message)
  end

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
