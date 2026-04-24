defmodule CanvasMcp.UserActor.CanvasHandler do
  require Logger

  alias CanvasMcp.Canvas.Course
  alias CanvasMcp.Canvas.Assignment
  alias CanvasMcp.Canvas.Submission
  alias CanvasMcp.UserActor.Helpers

  def handle({:get_canvas_courses, _}, %{canvas_token: nil} = state) do
    broadcast(state.user_id, {:canvas, :error, :no_canvas_token})
    {:noreply, state}
  end

  def handle({:get_canvas_courses, invalidate_cache}, %{canvas_token: token} = state) do
    case Course.get_all_courses(token, invalidate_cache) do
      {:ok, courses} ->
        broadcast(state.user_id, {:canvas, :courses_refreshed, courses})

      {:error, reason} ->
        Logger.error(
          "UserActor courses fetch failed for user_id=#{state.user_id}: #{inspect(reason)}"
        )

        broadcast(state.user_id, {:canvas, :error, reason})
    end

    {:noreply, state}
  end

  def handle({:get_course_assignments, course_id}, state) do
    case Map.get(state.assignments, course_id) do
      nil ->
        case Assignment.list_for_course(course_id) do
          {:ok, assignments} ->
            new_state = put_in(state.assignments[course_id], assignments)
            broadcast(state.user_id, {:canvas, :assignments_loaded, {course_id, assignments}})
            {:noreply, new_state}

          {:error, reason} ->
            Logger.error(
              "UserActor assignments fetch failed for course_id=#{course_id}: #{inspect(reason)}"
            )

            broadcast(state.user_id, {:canvas, :error, reason})
            {:noreply, state}
        end

      assignments ->
        broadcast(state.user_id, {:canvas, :assignments_loaded, {course_id, assignments}})
        {:noreply, state}
    end
  end

  def handle({:refresh_course_assignments, _course_id}, %{canvas_token: nil} = state) do
    broadcast(state.user_id, {:canvas, :error, :no_canvas_token})
    {:noreply, state}
  end

  def handle({:refresh_course_assignments, course_id}, %{canvas_token: token} = state) do
    case Assignment.fetch_and_store_for_course(course_id, token) do
      {:ok, assignments} ->
        new_state = put_in(state.assignments[course_id], assignments)
        broadcast(state.user_id, {:canvas, :assignments_loaded, {course_id, assignments}})
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error(
          "UserActor assignments refresh failed for course_id=#{course_id}: #{inspect(reason)}"
        )

        broadcast(state.user_id, {:canvas, :error, reason})
        {:noreply, state}
    end
  end

  def handle({:refresh_assignments_with_submissions, _course_id}, %{canvas_token: nil} = state) do
    broadcast(state.user_id, {:canvas, :error, :no_canvas_token})
    {:noreply, state}
  end

  def handle({:refresh_assignments_with_submissions, course_id}, %{canvas_token: token} = state) do
    case Assignment.fetch_and_store_for_course(course_id, token) do
      {:ok, assignments} ->
        new_state = put_in(state.assignments[course_id], assignments)
        broadcast(state.user_id, {:canvas, :assignments_loaded, {course_id, assignments}})

        final_state =
          assignments
          |> Enum.filter(&past_due?/1)
          |> Enum.reduce(new_state, fn assignment, acc ->
            if Map.has_key?(acc.submissions, assignment.id) do
              acc
            else
              case Submission.list_for_assignment(assignment.id) do
                {:ok, []} ->
                  case Submission.fetch_and_store_for_assignment(course_id, assignment.id, token) do
                    {:ok, submissions} ->
                      broadcast(
                        acc.user_id,
                        {:canvas, :submissions_loaded, {assignment.id, submissions}}
                      )

                      put_in(acc.submissions[assignment.id], submissions)

                    {:error, reason} ->
                      Logger.warning(
                        "Skipping submissions for assignment #{assignment.id}: #{inspect(reason)}"
                      )

                      acc
                  end

                {:ok, submissions} ->
                  put_in(acc.submissions[assignment.id], submissions)

                {:error, _} ->
                  acc
              end
            end
          end)

        {:noreply, final_state}

      {:error, reason} ->
        Logger.error(
          "UserActor assignments+submissions refresh failed for course_id=#{course_id}: #{inspect(reason)}"
        )

        broadcast(state.user_id, {:canvas, :error, reason})
        {:noreply, state}
    end
  end

  def handle({:get_assignment_submissions, assignment_id}, state) do
    case Map.get(state.submissions, assignment_id) do
      nil ->
        case Submission.list_for_assignment(assignment_id) do
          {:ok, submissions} ->
            new_state = put_in(state.submissions[assignment_id], submissions)
            broadcast(state.user_id, {:canvas, :submissions_loaded, {assignment_id, submissions}})
            {:noreply, new_state}

          {:error, reason} ->
            Logger.error(
              "UserActor submissions fetch failed for assignment_id=#{assignment_id}: #{inspect(reason)}"
            )

            broadcast(state.user_id, {:canvas, :error, reason})
            {:noreply, state}
        end

      submissions ->
        broadcast(state.user_id, {:canvas, :submissions_loaded, {assignment_id, submissions}})
        {:noreply, state}
    end
  end

  def handle(
        {:refresh_assignment_submissions, _course_id, _assignment_id},
        %{canvas_token: nil} = state
      ) do
    broadcast(state.user_id, {:canvas, :error, :no_canvas_token})
    {:noreply, state}
  end

  def handle(
        {:refresh_assignment_submissions, course_id, assignment_id},
        %{canvas_token: token} = state
      ) do
    case Submission.fetch_and_store_for_assignment(course_id, assignment_id, token) do
      {:ok, submissions} ->
        new_state = put_in(state.submissions[assignment_id], submissions)
        broadcast(state.user_id, {:canvas, :submissions_loaded, {assignment_id, submissions}})
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error(
          "UserActor submissions refresh failed for assignment_id=#{assignment_id}: #{inspect(reason)}"
        )

        broadcast(state.user_id, {:canvas, :error, reason})
        {:noreply, state}
    end
  end

  defp past_due?(%{due_at: nil}), do: false

  defp past_due?(%{due_at: due_at_str}) do
    case DateTime.from_iso8601(due_at_str) do
      {:ok, due_at, _} -> DateTime.before?(due_at, DateTime.utc_now())
      _ -> false
    end
  end

  defp broadcast(user_id, message), do: Helpers.broadcast(user_id, message)
end
