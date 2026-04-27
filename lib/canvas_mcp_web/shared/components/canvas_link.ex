defmodule CanvasMcpWeb.Components.CanvasLink do
  use Phoenix.Component

  attr :text, :string, required: true
  attr :destination, :string, required: true

  def canvas_link(assigns) do
    ~H"""
    <a
      href={@destination}
      target="_blank"
      rel="noopener noreferrer"
      class="inline-flex items-center gap-1.5 rounded-lg border border-slate-700 px-3 py-1.5 text-xs font-semibold text-slate-400 hover:bg-slate-800 hover:text-slate-200 hover:border-slate-500 transition-all"
    >
      <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
        />
      </svg>
      {@text}
    </a>
    """
  end
end
