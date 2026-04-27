defmodule CanvasMcpWeb.UserAuth do
  import Phoenix.LiveView
  import Phoenix.Component
  alias CanvasMcp.Data.User

  def on_mount(:ensure_authenticated, _params, session, socket) do
    case session["current_user_id"] && User.get_by_id(session["current_user_id"]) do
      {:ok, user} ->
        {:cont, assign(socket, :current_user, user)}

      _ ->
        socket =
          socket
          |> put_flash(:error, "Your session has expired. Please log in again.")
          |> redirect(to: "/auth/logout")

        {:halt, socket}
    end
  end
end
