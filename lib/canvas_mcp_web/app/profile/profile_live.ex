defmodule CanvasMcpWeb.App.ProfileLive do
  use CanvasMcpWeb, :live_view
  alias CanvasMcp.UserActor

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    {:ok, _pid} = UserActor.ensure_started(current_user.id)

    if connected?(socket) do
      UserActor.subscribe_to_user(current_user.id)
      UserActor.get_data(current_user.id)
    end

    socket =
      socket
      |> assign(:token_form, to_form(%{"canvas_token" => ""}))
      |> assign(:has_canvas_token, false)
      |> assign(:canvas_user, nil)
      |> assign(:token_message, nil)

    {:ok, socket}
  end

  @impl true
  def handle_info({:canvas, :data, user_data}, socket) do
    {:noreply,
     socket
     |> assign(:current_user, user_data.user || socket.assigns.current_user)
     |> assign_canvas_state(user_data)}
  end

  @impl true
  def handle_info({:canvas, :token_updated, user_data}, socket) do
    msg =
      cond do
        user_data.canvas_token && user_data.canvas_user ->
          {:ok, "Linked to #{user_data.canvas_user.name}."}

        user_data.canvas_token ->
          {:error, "Token saved but appears invalid — check it and try again."}

        true ->
          {:ok, "Token cleared."}
      end

    {:noreply,
     socket
     |> assign_canvas_state(user_data)
     |> assign(:token_form, to_form(%{"canvas_token" => ""}))
     |> assign(:token_message, msg)}
  end

  @impl true
  def handle_info({:canvas, :error, _reason}, socket) do
    {:noreply, assign(socket, :token_message, {:error, "An error occurred. Please try again."})}
  end

  @impl true
  def handle_event("save_canvas_token", %{"canvas_token" => token}, socket) do
    token = if token == "", do: nil, else: token
    UserActor.update_canvas_token(socket.assigns.current_user.id, token)
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_canvas_token", _params, socket) do
    UserActor.update_canvas_token(socket.assigns.current_user.id, nil)
    {:noreply, socket}
  end

  defp assign_canvas_state(socket, %{canvas_token: token, canvas_user: canvas_user}) do
    socket
    |> assign(:has_canvas_token, not is_nil(token))
    |> assign(:canvas_user, canvas_user)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} notifications={@notifications}>
      <div class="max-w-lg w-full mx-auto py-8 px-4 space-y-5">
        <div class="flex items-center gap-3 mb-2">
          <.link navigate={~p"/app"} class="text-slate-400 hover:text-slate-200 transition-colors">
            <.icon name="hero-arrow-left" class="size-5" />
          </.link>
          <h1 class="text-lg font-semibold text-slate-100">Profile & Settings</h1>
        </div>

        <%!-- Account card --%>
        <div class="rounded-2xl border border-slate-700 bg-slate-800 shadow-lg">
          <div class="px-6 py-4 border-b border-slate-700">
            <h2 class="text-sm font-semibold uppercase tracking-wider text-slate-400">Account</h2>
          </div>
          <div class="px-6 py-5 space-y-4">
            <div class="flex items-center justify-between">
              <span class="text-sm text-slate-400">Email</span>
              <span class="text-sm font-medium text-slate-100">{@current_user.email}</span>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-sm text-slate-400">Role</span>
              <span class={[
                "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold",
                @current_user.is_admin &&
                  "bg-indigo-500/20 text-indigo-300 ring-1 ring-indigo-500/30",
                !@current_user.is_admin && "bg-slate-700 text-slate-300"
              ]}>
                {if @current_user.is_admin, do: "Admin", else: "User"}
              </span>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-sm text-slate-400">Member since</span>
              <span class="text-sm text-slate-300 font-mono">
                {Calendar.strftime(@current_user.inserted_at, "%B %d, %Y")}
              </span>
            </div>
          </div>
        </div>

        <%!-- Canvas account card --%>
        <.canvas_user_display canvas_user={@canvas_user} />

        <%!-- Canvas token card --%>
        <div class="rounded-2xl border border-slate-700 bg-slate-800 shadow-lg">
          <div class="px-6 py-4 border-b border-slate-700">
            <h2 class="text-sm font-semibold uppercase tracking-wider text-slate-400">
              Canvas Integration
            </h2>
            <p class="mt-1.5 text-sm text-slate-400">
              Your personal Canvas LMS API token — used to access Canvas data on your behalf.
            </p>
          </div>
          <div class="px-6 py-5">
            <%= if @has_canvas_token do %>
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <span class="inline-block w-2 h-2 rounded-full bg-emerald-400"></span>
                  <span class="text-sm font-medium text-emerald-400">Token configured</span>
                </div>
                <button
                  type="button"
                  phx-click="clear_canvas_token"
                  class="rounded-lg border border-red-800/60 px-4 py-2 text-sm font-semibold text-red-400 hover:bg-red-900/30 hover:border-red-700 active:scale-95 transition-all"
                >
                  Clear Token
                </button>
              </div>
            <% else %>
              <.form
                for={@token_form}
                id="canvas-token-form"
                phx-submit="save_canvas_token"
                class="space-y-4"
              >
                <div>
                  <label
                    for="canvas-token-form_canvas_token"
                    class="block text-sm font-medium text-slate-300 mb-1.5"
                  >
                    API Token
                  </label>
                  <input
                    id="canvas-token-form_canvas_token"
                    name="canvas_token"
                    type="password"
                    value={@token_form[:canvas_token].value}
                    placeholder="Paste your Canvas API token here"
                    autocomplete="off"
                    class="block w-full rounded-lg border border-slate-600 bg-slate-900 px-3 py-2.5 text-sm text-slate-100 shadow-sm placeholder:text-slate-500 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 transition-colors"
                  />
                </div>
                <div class="pt-1">
                  <button
                    type="submit"
                    class="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 active:scale-95 transition-all"
                  >
                    Save Token
                  </button>
                </div>
              </.form>
            <% end %>
            <%= if @token_message do %>
              <p class={[
                "mt-3 flex items-center gap-1.5 text-sm",
                elem(@token_message, 0) == :ok && "text-emerald-400",
                elem(@token_message, 0) == :error && "text-red-400"
              ]}>
                <.icon
                  name={
                    if elem(@token_message, 0) == :ok,
                      do: "hero-check-circle",
                      else: "hero-exclamation-circle"
                  }
                  class="size-4 shrink-0"
                />
                {elem(@token_message, 1)}
              </p>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
