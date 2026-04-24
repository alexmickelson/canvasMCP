defmodule CanvasMcpWeb.App.HomeLive do
  use CanvasMcpWeb, :live_view
  require Logger
  alias CanvasMcp.UserActor

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]
    {:ok, _pid} = UserActor.ensure_started(current_user.id)

    if connected?(socket) do
      UserActor.subscribe_to_user(current_user.id)
      UserActor.get_data(current_user.id)
      UserActor.get_canvas_courses(current_user.id)
    end

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:courses, [])
      |> assign(:courses_status, nil)

    {:ok, socket}
  end

  @impl true
  def handle_info({:canvas, :data, user_data}, socket) do
    {:noreply, assign(socket, :current_user, user_data.user || socket.assigns.current_user)}
  end

  @impl true
  def handle_info({:canvas, :courses_refreshed, courses}, socket) do
    {:noreply,
     socket
     |> assign(:courses, courses)
     |> assign(:courses_status, :refreshed)}
  end

  @impl true
  def handle_info({:canvas, _event, _data}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_courses", _params, socket) do
    UserActor.get_canvas_courses(socket.assigns.current_user.id, true)
    {:noreply, assign(socket, :courses_status, :refreshing)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="px-6 py-8">
        <.all_courses courses={@courses} status={@courses_status} />
      </div>
    </Layouts.app>
    """
  end
end
