defmodule CanvasMcpWeb.CanvasComponents.CanvasUserDisplay do
  use Phoenix.Component

  attr :canvas_user, :map, required: true

  def canvas_user_display(assigns) do
    ~H"""
    <%= if @canvas_user do %>
      <div class="rounded-2xl border border-slate-700 bg-slate-800 shadow-lg mb-5">
        <div class="px-6 py-4 border-b border-slate-700 flex items-center justify-between">
          <h2 class="text-sm font-semibold uppercase tracking-wider text-slate-400">
            Canvas Account
          </h2>
          <span class="inline-flex items-center gap-1.5 text-xs font-medium text-emerald-400">
            <span class="inline-block w-1.5 h-1.5 rounded-full bg-emerald-400"></span> Linked
          </span>
        </div>
        <div class="px-6 py-5">
          <div class="flex items-center gap-4 mb-5">
            <%= if @canvas_user.avatar_url do %>
              <img
                src={@canvas_user.avatar_url}
                alt={@canvas_user.name}
                class="w-12 h-12 rounded-full ring-2 ring-slate-600 shrink-0"
              />
            <% else %>
              <div class="w-12 h-12 rounded-full bg-indigo-600 flex items-center justify-center text-white font-bold text-base shrink-0">
                {String.first(@canvas_user.name)}
              </div>
            <% end %>
            <div>
              <p class="text-base font-semibold text-slate-100">{@canvas_user.name}</p>
              <p class="text-sm text-slate-400">{@canvas_user[:login_id]}</p>
            </div>
          </div>
          <div class="space-y-3">
            <div class="flex items-center justify-between">
              <span class="text-sm text-slate-400">Canvas ID</span>
              <span class="text-sm font-mono text-slate-300">{@canvas_user.id}</span>
            </div>
            <%= if @canvas_user[:sis_user_id] do %>
              <div class="flex items-center justify-between">
                <span class="text-sm text-slate-400">SIS User ID</span>
                <span class="text-sm font-mono text-slate-300">{@canvas_user.sis_user_id}</span>
              </div>
            <% end %>
            <%= if @canvas_user[:time_zone] do %>
              <div class="flex items-center justify-between">
                <span class="text-sm text-slate-400">Time Zone</span>
                <span class="text-sm text-slate-300">{@canvas_user.time_zone}</span>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
