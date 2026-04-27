defmodule CanvasMcpWeb.UserNotifications do
  import Phoenix.Component
  import Phoenix.LiveView
  alias CanvasMcp.UserActor.Helpers

  def on_mount(:default, _params, _session, socket) do
    user_id = socket.assigns[:current_user] && socket.assigns.current_user.id

    socket = assign(socket, :notifications, [])

    if user_id do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(CanvasMcp.PubSub, Helpers.error_channel(user_id))
      end

      socket =
        attach_hook(socket, :user_notifications_info, :handle_info, fn
          {:user_error, message}, socket ->
            id = System.unique_integer([:positive, :monotonic])
            notif = %{id: id, message: message}
            Process.send_after(self(), {:dismiss_notification, id}, 5000)
            {:halt, update(socket, :notifications, &[notif | &1])}

          {:dismiss_notification, id}, socket ->
            {:halt, update(socket, :notifications, &Enum.reject(&1, fn n -> n.id == id end))}

          _other, socket ->
            {:cont, socket}
        end)

      socket =
        attach_hook(socket, :user_notifications_event, :handle_event, fn
          "dismiss_notification", %{"id" => id_str}, socket ->
            id = String.to_integer(id_str)
            {:halt, update(socket, :notifications, &Enum.reject(&1, fn n -> n.id == id end))}

          _other, _params, socket ->
            {:cont, socket}
        end)

      {:cont, socket}
    else
      {:cont, socket}
    end
  end
end
