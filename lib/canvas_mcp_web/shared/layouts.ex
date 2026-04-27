defmodule CanvasMcpWeb.Layouts do
  use CanvasMcpWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :current_user, :map, default: nil
  attr :notifications, :list, default: []
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex flex-col h-screen bg-slate-950 text-slate-100 overflow-hidden">
      <%!-- Top navigation bar --%>
      <header class="shrink-0 flex items-center justify-between px-5 h-14 border-b border-slate-800 bg-slate-900/80 backdrop-blur-sm">
        <.link
          navigate={~p"/app"}
          class="text-sm font-semibold text-slate-200 hover:text-white transition-colors"
        >
          CanvasMCP
        </.link>
        <%= if @current_user do %>
          <nav class="flex items-center gap-2">
            <.link
              navigate={~p"/app/profile"}
              class="flex items-center gap-2 rounded-lg px-3 py-1.5 text-sm text-slate-300 hover:bg-slate-800 hover:text-white transition-all"
            >
              <.icon name="hero-user-circle" class="size-4" />
              <span>{@current_user.email}</span>
            </.link>
            <.link
              href={~p"/auth/logout"}
              class="rounded-lg px-3 py-1.5 text-sm text-slate-400 hover:bg-slate-800 hover:text-white transition-all"
            >
              Logout
            </.link>
          </nav>
        <% end %>
      </header>
      <%!-- Page content --%>
      <main class="flex-1 overflow-y-auto">
        {render_slot(@inner_block)}
      </main>
    </div>
    <%!-- Toast notifications --%>
    <div
      id="user-notifications"
      aria-live="assertive"
      class="fixed bottom-4 right-4 z-50 flex flex-col gap-2 pointer-events-none"
    >
      <%= for notif <- @notifications do %>
        <div
          id={"notif-#{notif.id}"}
          class="pointer-events-auto flex items-start gap-3 rounded-lg bg-slate-800 border border-red-500/30 shadow-xl px-4 py-3 max-w-sm w-full"
        >
          <.icon name="hero-exclamation-circle" class="size-4 text-red-400 shrink-0 mt-0.5" />
          <p class="text-sm text-slate-200 flex-1 leading-snug">{notif.message}</p>
          <button
            phx-click="dismiss_notification"
            phx-value-id={notif.id}
            class="text-slate-500 hover:text-slate-300 transition-colors shrink-0 ml-1"
            aria-label="Dismiss"
          >
            <.icon name="hero-x-mark" class="size-3.5" />
          </button>
        </div>
      <% end %>
    </div>
    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />
      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
