defmodule CanvasMcpWeb.App.HomeLive do
  use CanvasMcpWeb, :live_view
  require Logger
  alias CanvasMcp.UserActor
  alias CanvasMcp.Data.User
  alias CanvasMcp.Data.ServiceAccount
  import CanvasMcpWeb.App.ServiceAccounts.ServiceAccountsPanel

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    {:ok, _pid} = UserActor.ensure_started(current_user.id)

    if connected?(socket) do
      UserActor.subscribe_to_user(current_user.id)
      UserActor.get_data(current_user.id)
      UserActor.get_canvas_courses(current_user.id)
    end

    socket =
      socket
      |> assign(:has_canvas_token, User.has_canvas_token?(current_user.id))
      |> assign(:courses, [])
      |> assign(:courses_status, nil)
      |> assign(:selected_term, nil)
      |> assign(:sa_name_form, to_form(%{"name" => ""}))
      |> assign(:sa_new_token, nil)
      |> assign(:sa_revoke_confirm, nil)
      |> assign(:sa_form_key, 0)
      |> stream_configure(:service_accounts, dom_id: &"service-account-#{&1["id"]}")
      |> stream(:service_accounts, service_accounts(current_user.id))

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
    Logger.debug(
      "home_live page unhandled canvas event: #{inspect(event)} with data #{inspect(data)} for user_id=#{socket.assigns.current_user.id}"
    )

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
  def handle_event("sa_create", %{"name" => name}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply,
       assign(
         socket,
         :sa_name_form,
         to_form(%{"name" => ""}, errors: [name: {"can't be blank", []}])
       )}
    else
      case ServiceAccount.create(socket.assigns.current_user.id, name) do
        {:ok, account, raw_token} ->
          {:noreply,
           socket
           |> stream_insert(:service_accounts, account, at: 0)
           |> assign(:sa_name_form, to_form(%{"name" => ""}))
           |> assign(:sa_form_key, socket.assigns.sa_form_key + 1)
           |> assign(:sa_new_token, %{name: account["name"], token: raw_token})}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to create service account.")}
      end
    end
  end

  @impl true
  def handle_event("sa_dismiss_token", _params, socket) do
    {:noreply, assign(socket, :sa_new_token, nil)}
  end

  @impl true
  def handle_event("sa_revoke_confirm", %{"id" => id, "name" => name}, socket) do
    {:noreply, assign(socket, :sa_revoke_confirm, %{"id" => id, "name" => name})}
  end

  @impl true
  def handle_event("sa_revoke_cancel", _params, socket) do
    {:noreply, assign(socket, :sa_revoke_confirm, nil)}
  end

  @impl true
  def handle_event("sa_revoke", %{"id" => id}, socket) do
    case ServiceAccount.revoke(id, socket.assigns.current_user.id) do
      :ok ->
        {:noreply,
         socket
         |> assign(:sa_revoke_confirm, nil)
         |> stream_delete_by_dom_id(:service_accounts, "service-account-#{id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to revoke service account.")}
    end
  end

  defp service_accounts(user_id) do
    case ServiceAccount.list_for_user(user_id) do
      {:ok, list} -> list
      _ -> []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} notifications={@notifications}>
      <div class="px-6 py-8 space-y-10">
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

        <div class="border-t border-slate-800 pt-8">
          <.service_accounts_panel
            name_form={@sa_name_form}
            new_token={@sa_new_token}
            accounts_stream={@streams.service_accounts}
            revoke_confirm={@sa_revoke_confirm}
            form_key={@sa_form_key}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end
end
