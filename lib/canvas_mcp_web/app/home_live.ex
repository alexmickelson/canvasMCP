defmodule CanvasMcpWeb.App.HomeLive do
  use CanvasMcpWeb, :live_view
  require Logger
  alias CanvasMcp.UserActor
  alias CanvasMcp.Data.User

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
      |> assign(:has_canvas_token, User.has_canvas_token?(current_user.id))
      |> assign(:courses, [])
      |> assign(:courses_status, nil)
      |> assign(:selected_term, nil)

    {:ok, socket}
  end

  @impl true
  def handle_info({:canvas, :data, user_data}, socket) do
    user = user_data.user || socket.assigns.current_user

    {:noreply,
     socket
     |> assign(:current_user, user)
     |> assign(:has_canvas_token, not is_nil(user_data.canvas_token))}
  end

  @impl true
  def handle_info({:canvas, :courses_refreshed, courses}, socket) do
    selected_term =
      socket.assigns.selected_term ||
        CanvasMcpWeb.App.Courses.TermSelector.default_term(courses)

    {:noreply,
     socket
     |> assign(:courses, courses)
     |> assign(:selected_term, selected_term)
     |> assign(:courses_status, :refreshed)}
  end

  @impl true
  def handle_info({:canvas, :token_updated, state}, socket) do
    user = state.user || socket.assigns.current_user

    {:noreply,
     socket
     |> assign(:current_user, user)
     |> assign(:has_canvas_token, not is_nil(state.canvas_token))}
  end

  @impl true
  def handle_info({:canvas, event, data}, socket) do
    Logger.debug("home_live page unhandled canvas event: #{inspect(event)} with data #{inspect(data)} for user_id=#{socket.assigns.current_user.id}")
    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_courses", _params, socket) do
    UserActor.get_canvas_courses(socket.assigns.current_user.id, true)
    {:noreply, assign(socket, :courses_status, :refreshing)}
  end

  @impl true
  def handle_event("select_term", %{"term" => term}, socket) do
    {:noreply, assign(socket, :selected_term, term)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="px-6 py-8 space-y-6">
        <%= if not @has_canvas_token do %>
          <div class="rounded-xl border border-amber-700/40 bg-amber-950/20 px-5 py-4 flex items-start gap-3">
            <svg
              class="w-4 h-4 text-amber-400 shrink-0 mt-0.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M12 9v2m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"
              />
            </svg>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-amber-300">Canvas token not connected</p>
              <p class="text-xs text-amber-500/80 mt-0.5">
                Course data cannot be synced. Connect your Canvas API token to load assignments and submissions.
              </p>
            </div>
            <.link
              navigate="/app/profile"
              class="shrink-0 inline-flex items-center gap-1.5 rounded-lg border border-amber-600/60 px-3 py-1.5 text-xs font-semibold text-amber-400 hover:bg-amber-900/40 hover:border-amber-500 transition-all"
            >
              Connect token
            </.link>
          </div>
        <% else %>
          <.all_courses courses={@courses} status={@courses_status} selected_term={@selected_term} />
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
