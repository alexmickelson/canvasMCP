defmodule CanvasMcpWeb.App.Courses.AssignmentLive do
  use CanvasMcpWeb, :live_view
  alias CanvasMcp.UserActor
  alias CanvasMcp.Canvas.Assignment
  alias CanvasMcpWeb.Layouts
  import CanvasMcpWeb.App.Courses.SubmissionsPanel
  @impl true
  def mount(%{"course_id" => course_id, "id" => id}, session, socket) do
    current_user = session["current_user"]
    {:ok, _pid} = UserActor.ensure_started(current_user.id)

    course_id = String.to_integer(course_id)
    assignment_id = String.to_integer(id)

    if connected?(socket) do
      UserActor.subscribe_to_user(current_user.id)
      UserActor.get_assignment_submissions(current_user.id, assignment_id)
    end

    assignment =
      case Assignment.get_by_id(assignment_id) do
        {:ok, a} -> a
        _ -> nil
      end

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:course_id, course_id)
      |> assign(:assignment_id, assignment_id)
      |> assign(:assignment, assignment)
      |> assign(:submissions_list, [])
      |> assign(:submissions_status, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:canvas, :submissions_loaded, {assignment_id, submissions}}, socket) do
    if assignment_id == socket.assigns.assignment_id do
      {:noreply,
       socket
       |> assign(:submissions_status, :loaded)
       |> assign(:submissions_list, submissions)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("refresh_submissions", _params, socket) do
    UserActor.refresh_assignment_submissions(
      socket.assigns.current_user.id,
      socket.assigns.course_id,
      socket.assigns.assignment_id
    )

    {:noreply, assign(socket, :submissions_status, :refreshing)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="px-6 py-8 max-w-4xl mx-auto space-y-6">
        <%!-- Breadcrumb --%>
        <div class="flex items-center gap-2 text-xs">
          <.link
            navigate="/app"
            class="text-slate-600 hover:text-slate-400 transition-colors"
          >
            Courses
          </.link>
          <span class="text-slate-700">/</span>
          <.link
            navigate={"/app/courses/#{@course_id}"}
            class="text-slate-600 hover:text-slate-400 transition-colors"
          >
            {if @assignment, do: @assignment.course_id, else: @course_id}
          </.link>
          <span class="text-slate-700">/</span>
          <%= if @assignment do %>
            <span class="text-slate-400 truncate">{@assignment.name}</span>
          <% else %>
            <div class="h-3.5 w-32 rounded bg-slate-800 animate-pulse"></div>
          <% end %>
        </div>

        <%= if @assignment do %>
          <%!-- Header --%>
          <div class="space-y-3">
            <div class="flex items-start justify-between gap-4">
              <h1 class="text-xl font-bold text-slate-100 leading-snug">{@assignment.name}</h1>
              <span class={[
                "shrink-0 inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium",
                @assignment.published && "bg-emerald-500/15 text-emerald-400",
                !@assignment.published && "bg-slate-700 text-slate-400"
              ]}>
                {if @assignment.published, do: "Published", else: "Draft"}
              </span>
            </div>
            <div class="flex flex-wrap items-center gap-4 text-xs text-slate-500">
              <%= if @assignment.due_at do %>
                <span>
                  Due: <span class="text-slate-300">{format_datetime(@assignment.due_at)}</span>
                </span>
              <% end %>
              <%= if @assignment.points_possible do %>
                <span>Points: <span class="text-slate-300">{@assignment.points_possible}</span></span>
              <% end %>
              <%= if @assignment.grading_type do %>
                <span>Grading: <span class="text-slate-300">{@assignment.grading_type}</span></span>
              <% end %>
            </div>
          </div>

          <.submissions_panel
            submissions={@submissions_list}
            status={@submissions_status}
            course_id={@course_id}
            assignment_id={@assignment_id}
          />

          <%!-- Description --%>
          <%= if @assignment.description do %>
            <div class="rounded-xl border border-slate-700 bg-slate-800/60 p-5 overflow-x-auto">
              <div class="assignment-body">
                {Phoenix.HTML.raw(@assignment.description)}
              </div>
            </div>
          <% else %>
            <div class="rounded-2xl border border-slate-700 border-dashed bg-slate-800/40 px-6 py-10 text-center">
              <p class="text-sm text-slate-500">No description provided.</p>
            </div>
          <% end %>
        <% else %>
          <div class="rounded-2xl border border-slate-700 border-dashed bg-slate-800/40 px-6 py-14 text-center">
            <p class="text-sm text-slate-500">Assignment not found.</p>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
