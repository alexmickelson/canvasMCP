defmodule CanvasMcp.UserActor.CanvasHandler do
  require Logger

  alias CanvasMcp.Canvas.Course
  alias CanvasMcp.Canvas.Assignment
  alias CanvasMcp.Canvas.Enrollment
  alias CanvasMcp.Canvas.Submission
  alias CanvasMcp.Canvas.Rubric
  alias CanvasMcp.UserActor.Helpers

  def handle({:get_canvas_courses, _}, %{canvas_token: nil} = state) do
    Helpers.broadcast(state.user_id, {:canvas, :error, :no_canvas_token})
    {:noreply, state}
  end

  def handle({:get_canvas_courses, invalidate_cache}, %{canvas_token: token} = state) do
    case Course.get_all_courses(token, invalidate_cache) do
      {:ok, courses} ->
        Helpers.broadcast(state.user_id, {:canvas, :courses_refreshed, courses})

      {:error, reason} ->
        Logger.error(
          "UserActor courses fetch failed for user_id=#{state.user_id}: #{inspect(reason)}"
        )

        Helpers.broadcast(state.user_id, {:canvas, :error, reason})
    end

    {:noreply, state}
  end

  def handle({:get_course_assignments, course_id}, state) do
    case Map.get(state.assignments, course_id) do
      nil ->
        case Assignment.list_for_course(course_id) do
          {:ok, assignments} ->
            new_state = put_in(state.assignments[course_id], assignments)

            Helpers.broadcast(
              state.user_id,
              {:canvas, :assignments_loaded, {course_id, assignments}}
            )

            {:noreply, new_state}

          {:error, reason} ->
            Logger.error(
              "UserActor assignments fetch failed for course_id=#{course_id}: #{inspect(reason)}"
            )

            Helpers.broadcast(state.user_id, {:canvas, :error, reason})
            {:noreply, state}
        end

      assignments ->
        Helpers.broadcast(state.user_id, {:canvas, :assignments_loaded, {course_id, assignments}})
        {:noreply, state}
    end
  end

  def handle({:refresh_course_assignments, _course_id}, %{canvas_token: nil} = state) do
    Helpers.broadcast(state.user_id, {:canvas, :error, :no_canvas_token})
    {:noreply, state}
  end

  def handle({:refresh_course_assignments, course_id}, %{canvas_token: token} = state) do
    case Assignment.fetch_and_store_for_course(course_id, token) do
      {:ok, assignments} ->
        new_state = put_in(state.assignments[course_id], assignments)
        Helpers.broadcast(state.user_id, {:canvas, :assignments_loaded, {course_id, assignments}})
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error(
          "UserActor assignments refresh failed for course_id=#{course_id}: #{inspect(reason)}"
        )

        Helpers.broadcast(state.user_id, {:canvas, :error, reason})
        {:noreply, state}
    end
  end

  def handle({:refresh_assignments_with_submissions, _course_id}, %{canvas_token: nil} = state) do
    Helpers.broadcast(state.user_id, {:canvas, :error, :no_canvas_token})
    {:noreply, state}
  end

  def handle({:refresh_assignments_with_submissions, course_id}, %{canvas_token: token} = state) do
    case Assignment.fetch_and_store_for_course(course_id, token) do
      {:ok, assignments} ->
        new_state = put_in(state.assignments[course_id], assignments)
        Helpers.broadcast(state.user_id, {:canvas, :assignments_loaded, {course_id, assignments}})
        sub_state = refresh_submissions_for_past_due(assignments, course_id, token, new_state)
        final_state = refresh_enrollments_for_course(course_id, token, sub_state)
        {:noreply, final_state}

      {:error, reason} ->
        Logger.error(
          "UserActor assignments+submissions refresh failed for course_id=#{course_id}: #{inspect(reason)}"
        )

        Helpers.broadcast(state.user_id, {:canvas, :error, reason})
        {:noreply, state}
    end
  end

  def handle({:get_course_enrollments, course_id}, state) do
    case Map.get(state.enrollments, course_id) do
      nil ->
        case Enrollment.list_for_course(course_id) do
          {:ok, []} ->
            {:noreply, state}

          {:ok, enrollments} ->
            Helpers.broadcast(
              state.user_id,
              {:canvas, :enrollments_loaded, {course_id, enrollments}}
            )

            {:noreply, put_in(state.enrollments[course_id], enrollments)}

          {:error, reason} ->
            Logger.error(
              "UserActor enrollments fetch failed for course_id=#{course_id}: #{inspect(reason)}"
            )

            {:noreply, state}
        end

      enrollments ->
        Helpers.broadcast(state.user_id, {:canvas, :enrollments_loaded, {course_id, enrollments}})
        {:noreply, state}
    end
  end

  def handle({:refresh_course_enrollments, _course_id}, %{canvas_token: nil} = state) do
    Helpers.broadcast(state.user_id, {:canvas, :error, :no_canvas_token})
    {:noreply, state}
  end

  def handle({:refresh_course_enrollments, course_id}, %{canvas_token: token} = state) do
    case Enrollment.fetch_and_store_for_course(course_id, token) do
      {:ok, enrollments} ->
        Helpers.broadcast(state.user_id, {:canvas, :enrollments_loaded, {course_id, enrollments}})
        {:noreply, put_in(state.enrollments[course_id], enrollments)}

      {:error, reason} ->
        Logger.error(
          "UserActor enrollments refresh failed for course_id=#{course_id}: #{inspect(reason)}"
        )

        Helpers.broadcast(state.user_id, {:canvas, :error, reason})
        {:noreply, state}
    end
  end

  def handle({:broadcast_cached_submissions, assignment_ids}, state) do
    new_state =
      Enum.reduce(assignment_ids, state, fn assignment_id, acc ->
        load_and_broadcast_cached_submission(acc, assignment_id)
      end)

    {:noreply, new_state}
  end

  def handle({:get_assignment_submissions, assignment_id}, state) do
    case Map.get(state.submissions, assignment_id) do
      nil ->
        case Submission.list_for_assignment(assignment_id) do
          {:ok, submissions} ->
            Helpers.broadcast(
              state.user_id,
              {:canvas, :submissions_loaded, {assignment_id, submissions}}
            )

            {:noreply, put_in(state.submissions[assignment_id], submissions)}

          {:error, reason} ->
            Logger.error(
              "UserActor submissions fetch failed for assignment_id=#{assignment_id}: #{inspect(reason)}"
            )

            Helpers.broadcast(state.user_id, {:canvas, :error, reason})
            {:noreply, state}
        end

      submissions ->
        Helpers.broadcast(
          state.user_id,
          {:canvas, :submissions_loaded, {assignment_id, submissions}}
        )

        {:noreply, state}
    end
  end

  def handle(
        {:refresh_assignment_submissions, _course_id, _assignment_id},
        %{canvas_token: nil} = state
      ) do
    Helpers.broadcast(state.user_id, {:canvas, :error, :no_canvas_token})
    {:noreply, state}
  end

  def handle(
        {:get_rubric_for_assignment, _course_id, _assignment_id},
        %{canvas_token: nil} = state
      ) do
    {:noreply, state}
  end

  def handle(
        {:get_rubric_for_assignment, course_id, assignment_id},
        %{canvas_token: token} = state
      ) do
    case Rubric.get_for_assignment(assignment_id) do
      {:ok, rubric} ->
        Helpers.broadcast(state.user_id, {:canvas, :rubric_loaded, {assignment_id, rubric}})

      _ ->
        case Rubric.fetch_and_store_for_assignment(course_id, assignment_id, token) do
          {:ok, rubric} ->
            Helpers.broadcast(state.user_id, {:canvas, :rubric_loaded, {assignment_id, rubric}})

          {:error, {:parse_error, _} = reason} ->
            Logger.warning(
              "Rubric parse failed for assignment #{assignment_id}: #{inspect(reason)}"
            )

            Helpers.broadcast_error(
              state.user_id,
              "Failed to load rubric — Canvas returned data in an unexpected format."
            )

          {:error, reason} ->
            Logger.debug("No rubric for assignment #{assignment_id}: #{inspect(reason)}")
        end
    end

    {:noreply, state}
  end

  def handle(
        {:refresh_assignment_submissions, course_id, assignment_id},
        %{canvas_token: token} = state
      ) do
    case Submission.fetch_and_store_for_assignment(course_id, assignment_id, token) do
      {:ok, submissions} ->
        Helpers.broadcast(
          state.user_id,
          {:canvas, :submissions_loaded, {assignment_id, submissions}}
        )

        {:noreply, put_in(state.submissions[assignment_id], submissions)}

      {:error, reason} ->
        Logger.error(
          "UserActor submissions refresh failed for assignment_id=#{assignment_id}: #{inspect(reason)}"
        )

        Helpers.broadcast(state.user_id, {:canvas, :error, reason})
        {:noreply, state}
    end
  end

  defp refresh_submissions_for_past_due(assignments, course_id, token, state) do
    assignments
    |> Enum.filter(&past_due?/1)
    |> Enum.reduce(state, fn assignment, acc ->
      fetch_or_load_submission(acc, assignment.id, course_id, token)
    end)
  end

  defp fetch_or_load_submission(state, assignment_id, course_id, token) do
    case Map.get(state.submissions, assignment_id) do
      nil ->
        fetch_submission_from_db_or_api(state, assignment_id, course_id, token)

      submissions ->
        Helpers.broadcast(
          state.user_id,
          {:canvas, :submissions_loaded, {assignment_id, submissions}}
        )

        state
    end
  end

  defp fetch_submission_from_db_or_api(state, assignment_id, course_id, token) do
    case Submission.list_for_assignment(assignment_id) do
      {:ok, []} ->
        fetch_submission_from_api(state, assignment_id, course_id, token)

      {:ok, submissions} ->
        Helpers.broadcast(
          state.user_id,
          {:canvas, :submissions_loaded, {assignment_id, submissions}}
        )

        put_in(state.submissions[assignment_id], submissions)

      {:error, _} ->
        state
    end
  end

  defp fetch_submission_from_api(state, assignment_id, course_id, token) do
    case Submission.fetch_and_store_for_assignment(course_id, assignment_id, token) do
      {:ok, submissions} ->
        Helpers.broadcast(
          state.user_id,
          {:canvas, :submissions_loaded, {assignment_id, submissions}}
        )

        put_in(state.submissions[assignment_id], submissions)

      {:error, reason} ->
        Logger.warning("Skipping submissions for assignment #{assignment_id}: #{inspect(reason)}")
        state
    end
  end

  defp load_and_broadcast_cached_submission(state, assignment_id) do
    case Map.get(state.submissions, assignment_id) do
      nil ->
        load_submission_from_db(state, assignment_id)

      submissions ->
        Helpers.broadcast(
          state.user_id,
          {:canvas, :submissions_loaded, {assignment_id, submissions}}
        )

        state
    end
  end

  defp load_submission_from_db(state, assignment_id) do
    case Submission.list_for_assignment(assignment_id) do
      {:ok, []} ->
        state

      {:ok, submissions} ->
        Helpers.broadcast(
          state.user_id,
          {:canvas, :submissions_loaded, {assignment_id, submissions}}
        )

        put_in(state.submissions[assignment_id], submissions)

      {:error, _} ->
        state
    end
  end

  defp refresh_enrollments_for_course(course_id, token, state) do
    case Enrollment.fetch_and_store_for_course(course_id, token) do
      {:ok, enrollments} ->
        Helpers.broadcast(state.user_id, {:canvas, :enrollments_loaded, {course_id, enrollments}})
        put_in(state.enrollments[course_id], enrollments)

      {:error, reason} ->
        Logger.warning("Enrollment refresh failed for course_id=#{course_id}: #{inspect(reason)}")
        state
    end
  end

  defp past_due?(%{due_at: nil}), do: false

  defp past_due?(%{due_at: due_at_str}) do
    case DateTime.from_iso8601(due_at_str) do
      {:ok, due_at, _} -> DateTime.before?(due_at, DateTime.utc_now())
      _ -> false
    end
  end
end
