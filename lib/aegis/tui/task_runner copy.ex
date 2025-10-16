# defmodule Aegis.Tui.TaskRunner do
#   @moduledoc """
#   Terminal User Interface para ejecutar tareas en paralelo que aprovecha toda la infraestructura de Pandr.Tui.

#   Este módulo reutiliza componentes existentes de Pandr.Tui:
#   - `Pandr.Tui.Terminal` para el manejo del terminal raw mode
#   - `Pandr.Tui.Renderer` para renderizado posicional
#   - `Pandr.Tui.LogoCache` para cache del logo
#   - Layout consistente con el resto del sistema TUI

#   Funcionalidades:
#   - Visualización en tiempo real de progreso de tareas paralelas
#   - Control de salida de procesos en segundo plano
#   - Renderizado optimizado con infraestructura TUI existente
#   - Layout consistente con menú principal (logo + contenido)
#   - Soporte dual: modo normal y modo raw
#   """

#   alias Aegis.Tui.{Terminal, Renderer, LogoCache}
#   alias Aegis.Printer
#   require Logger

#   @refresh_interval 500

#   @logo_start_x 2
#   @logo_start_y 2
#   @table_start_x 40
#   @table_start_y 5
#   @header_offset 0
#   @separator_top_offset 0
#   @table_headers_offset 2
#   @separator_bottom_offset 2
#   @first_row_offset 4
#   @summary_spacing 3
#   @first_col_width 30
#   @second_col_width 45
#   @third_col_width 75
#   @description_size 30
#   @step_size 50
#   @status_size 15

#   @status_labels %{
#     :pending => "Pending",
#     :processing => "Processing",
#     :success => "Success",
#     :error => "Error"
#   }

#   ============================
#   API Principal
#   ============================
#   @doc """
#   Ejecuta tareas en paralelo mostrando tabla de progreso en tiempo real.

#   Parámetros:
#   - `task_descriptions`: lista de {desc, fn(callback)}
#   - `opts`: header, refresh_interval, stderr_to_stdout, mode, auto_resize
#   """
#   def run(task_descriptions, opts \\ []) do
#     header = Keyword.get(opts, :header, "Procesando tareas en paralelo")
#     description = Keyword.get(opts, :description, nil)
#     refresh_interval = Keyword.get(opts, :refresh_interval, @refresh_interval)
#     auto_resize = Keyword.get(opts, :auto_resize, true)

#     if auto_resize, do: _resize_terminal(length(task_descriptions))

#     initial_state =
#       task_descriptions
#       |> Enum.with_index()
#       |> Enum.map(fn {{description, _func}, index} ->
#         %{
#           id: index,
#           description: description,
#           status: :pending,
#           progress: 0,
#           step: ""
#         }
#       end)

#     run_with_raw_mode(task_descriptions, initial_state, header, description, refresh_interval)
#   end

#   ============================
#   Sistema de notificaciones
#   ============================
#   def notify_progress(callback, percentage, message \\ nil) when is_integer(percentage) do
#     callback.(percentage)
#     if message, do: callback.({:step, message})
#     :ok
#   end

#   def notify_step(callback, step_name, details \\ nil) do
#     step_text = if details, do: "#{step_name}: #{details}", else: step_name
#     callback.({:step, step_text})
#     :ok
#   end

#   def notify_status(callback, status, context \\ %{}) do
#     callback.({:status, status})
#     if map_size(context) > 0, do: callback.({:context, context})
#     :ok
#   end

#   def notify_completion(callback, result, metadata \\ %{}) do
#     callback.({:complete, result})
#     if map_size(metadata) > 0, do: callback.({:metadata, metadata})
#     result
#   end

#   def notify_error(callback, error, recovery_options \\ []) do
#     callback.({:error, error})
#     if length(recovery_options) > 0, do: callback.({:recovery_options, recovery_options})
#     :ok
#   end

#   def notify_warning(callback, warning, severity \\ :medium) do
#     callback.({:warning, warning})
#     callback.({:severity, severity})
#     :ok
#   end

#   def notify_info(callback, info, category \\ :general) do
#     callback.({:info, info})
#     callback.({:category, category})
#     :ok
#   end

#   def notify_custom(callback, type, data, options \\ []) do
#     callback.({:custom, type, data})
#     if length(options) > 0, do: callback.({:custom_options, options})
#     :ok
#   end

#   ============================
#   Implementación interna
#   ============================
#   defp run_with_raw_mode(task_descriptions, initial_state, header, description, refresh_interval) do
#     Terminal.with_terminal(fn ->
#       _ensure_logo_cache()
#       ui_pid = spawn_link(fn -> _ui_loop(initial_state, header, refresh_interval, nil) end)
#       task_results = _execute_tasks(task_descriptions, ui_pid)
#       send(ui_pid, :stop)
#       _render_final_screen(initial_state, task_results, header, description)
#       _transform_results_for_api(task_results)
#     end)
#   end

#   defp _resize_terminal(_task_count), do: :ok

#   defp _ensure_logo_cache do
#     case GenServer.whereis(LogoCache) do
#       nil -> {:ok, _pid} = LogoCache.start_link()
#       _ -> :ok
#     end

#     if LogoCache.get_logo() == nil do
#       alias Aegis.Tui.MenuBuilder
#       LogoCache.set_logo(MenuBuilder.generate_menu_logo())
#     end
#   end

#   defp _execute_tasks(task_descriptions, ui_pid) do
#     tasks =
#       task_descriptions
#       |> Enum.with_index()
#       |> Enum.map(fn {{description, func}, index} ->
#         Task.async(fn ->
#           try do
#             result = _execute_task(func, fn progress -> send(ui_pid, {:progress_update, index, progress}) end)
#             send(ui_pid, {:progress_update, index, {:complete, result}})
#             {description, :success, result}
#           rescue
#             error ->
#               send(ui_pid, {:progress_update, index, {:error, error}})
#               Logger.error("Task #{description} failed: #{inspect(error)}")
#               {description, :error, error}
#           end
#         end)
#       end)

#     Task.await_many(tasks, :infinity)
#   end

#   defp _execute_task(func, progress_callback) do
#     original_group_leader = Process.group_leader()
#     original_logger_level = Logger.level()
#     {:ok, null_device} = StringIO.open("", [:write])

#     try do
#       Process.group_leader(self(), null_device)
#       Logger.configure(level: :emergency)
#       func.(progress_callback)
#     after
#       Process.group_leader(self(), original_group_leader)
#       Logger.configure(level: original_logger_level)
#       StringIO.close(null_device)
#     end
#   end

#   defp _transform_results_for_api(task_results) do
#     Enum.map(task_results, fn
#       {_desc, :success, result} -> result
#       {_desc, :success_with_warnings, result} -> result
#       {desc, :error, _} -> {desc, :error}
#       {_desc, _status, result} -> result
#     end)
#   end

#   ============================
#   UI loop
#   ============================
#   defp _ui_loop(state, header, refresh_interval, previous_state) do
#     receive do
#       {:progress_update, task_id, progress_info} ->
#         new_state = _update_task_state(state, task_id, progress_info)
#         _render_async_ui(new_state, header, state)
#         _ui_loop(new_state, header, refresh_interval, state)
#       :stop -> :ok
#     after
#       refresh_interval ->
#         if is_nil(previous_state), do: _render_async_ui(state, header, nil)
#         _ui_loop(state, header, refresh_interval, state)
#     end
#   end

#   defp _update_task_state(state, task_id, progress_info) do
#     Enum.map(state, fn task ->
#       if task.id == task_id do
#         case progress_info do
#           {:step, step} -> %{task | step: step, status: :processing}
#           progress when is_integer(progress) -> %{task | progress: progress, status: :processing}
#           {:status, s} -> %{task | status: s}
#           {:complete, _} -> %{task | status: :success, progress: 100}
#           {:error, _} -> %{task | status: :error, progress: 0}
#           {:context, _} -> task
#           {:metadata, _} -> task
#           {:recovery_options, _} -> task
#           {:severity, sev} -> %{task | status: if(sev in [:high, :critical], do: :error, else: :success)}
#           {:category, _} -> task
#           {:custom, _t, _d} -> task
#           {:custom_options, _} -> task
#           {:warning, w} -> %{task | status: :success, step: "Warning: #{w}"}
#           {:info, i} -> %{task | step: i}
#           _ -> task
#         end
#       else
#         task
#       end
#     end)
#   end

#   defp _render_async_ui(current_state, header, previous_state) do
#     if previous_state == nil, do: _initialize_async_screen(current_state, header), else: _update_changed_task_rows(current_state, previous_state)
#   end

#   defp _initialize_async_screen(state, header) do
#     IO.write("\e[2J\e[H\e[?25l")
#     Process.sleep(50)
#     Renderer.render_logo(LogoCache.get_logo() || [], @logo_start_y, @logo_start_x)
#     _render_async_header(header, @table_start_y)
#     _render_async_table_headers(@table_start_y)
#     _render_all_task_rows(state, @table_start_y)
#     IO.write("\e[?12l\e[?25l")
#   end

#   defp _update_changed_task_rows(current_state, previous_state) do
#     Enum.each(_find_state_changes(current_state, previous_state), fn {task_id, task} ->
#       _render_task_row(task_id, task, @table_start_y)
#     end)
#   end

#   defp _render_async_header(header, table_start_y) do
#     Printer.write_colored_at(header, pos_x: @table_start_x, pos_y: table_start_y + @header_offset, color: :info)
#   end

#   defp _render_async_table_headers(table_start_y) do
#     Printer.write_at(String.duplicate("─", 90), @table_start_x - 1, table_start_y + @separator_top_offset)
#     Printer.write_at(String.duplicate("─", 90), @table_start_x - 1, table_start_y + @separator_bottom_offset)
#     Printer.write_colored_at("Task", pos_x: @table_start_x, pos_y: table_start_y + @table_headers_offset)
#     Printer.write_colored_at("Status", pos_x: @table_start_x + @first_col_width, pos_y: table_start_y + @table_headers_offset)
#     Printer.write_colored_at("Progress", pos_x: @table_start_x + @second_col_width, pos_y: table_start_y + @table_headers_offset)
#     Printer.write_colored_at("Step", pos_x: @table_start_x + @third_col_width, pos_y: table_start_y + @table_headers_offset)
#   end

#   defp _render_all_task_rows(state, table_start_y) do
#     Enum.with_index(state)
#     |> Enum.each(fn {task, index} -> _render_task_row(index, task, table_start_y) end)
#   end

#   defp _render_task_row(task_id, task, table_start_y) do
#     row_y = table_start_y + @first_row_offset + task_id

#     Limpiar línea antes de escribir nuevos contenidos
#     Printer.write_at("                                                                                                ", @table_start_x, row_y)

#     String.slice(task.description, 0, @description_size)
#     |> String.pad_trailing(@description_size, " ")
#     |> Printer.write_colored_at(pos_x: @table_start_x, pos_y: row_y, color: :secondary)

#     status_text = Map.get(@status_labels, task.status, "") |> String.pad_trailing(@status_size, " ")
#     Printer.write_colored_at(status_text, pos_x: @table_start_x + @first_col_width, pos_y: row_y, color: task.status)

#     progress_text = Printer.render_progress_bar(task.progress)
#     Printer.write_colored_at(progress_text, pos_x: @table_start_x + @second_col_width, pos_y: row_y, color: task.status)

#     String.slice(task.step, 0, @step_size)
#     |> String.pad_trailing(@step_size, " ")
#     |> Printer.write_colored_at(pos_x: @table_start_x + @third_col_width, pos_y: row_y, color: :secondary)
#   end

#   defp _find_state_changes(current_state, previous_state) do
#     Enum.with_index(current_state)
#     |> Enum.filter(fn {cur, idx} ->
#       prev = Enum.at(previous_state, idx)
#       prev == nil or cur.status != prev.status or cur.progress != prev.progress or cur.step != prev.step
#     end)
#     |> Enum.map(fn {task, idx} -> {idx, task} end)
#   end

#   ============================
#   Pantalla final
#   ============================
#   defp _render_final_screen(initial_state, results, header, description) do
#     final_state =
#       Enum.with_index(initial_state)
#       |> Enum.map(fn {task, idx} ->
#         case Enum.at(results, idx) do
#           {_n, :success, _} -> %{task | status: :success, progress: 100}
#           {_n, :success_with_warnings, _} -> %{task | status: :success, progress: 100}
#           {_n, :error, _} -> %{task | status: :error, progress: 0}
#           _ -> %{task | status: :success, progress: 100}
#         end
#       end)

#     _render_async_ui(final_state, "#{header} - Completado", nil)
#     _render_completion_message(final_state, description)
#     _wait_for_return_to_menu()
#   end

#   defp _render_completion_message(final_state, description) do
#     success_count = Enum.count(final_state, &(&1.status == :success))
#     error_count = Enum.count(final_state, &(&1.status == :error))
#     table_end_y = @table_start_y + @first_row_offset + length(final_state) - 1
#     summary_y = table_end_y + @summary_spacing

#     Mensaje de resumen de tareas
#     summary_text = if error_count == 0,
#       do: "[✓] - Todas las tareas completadas exitosamente (#{success_count}/#{length(final_state)})",
#       else: "[✗] - #{success_count} completadas, #{error_count} fallaron"

#     color = if error_count == 0, do: :success, else: :error
#     Printer.write_colored_at(summary_text, pos_x: @table_start_x, pos_y: summary_y, color: color)

#     Renderiza description si existe
#     if description do
#       desc_text =
#         case description do
#           fun when is_function(fun, 0) -> fun.()   # función que devuelve string
#           text when is_binary(text) -> text        # string directo
#           _ -> nil
#         end

#       if desc_text do
#         Printer.write_colored_at(desc_text, pos_x: @table_start_x, pos_y: summary_y + 1, color: :info)
#       end
#     end

#     Mensaje de retorno al menú
#     return_y = summary_y + @summary_spacing
#     Printer.write_colored_at("Presiona [ENTER] para regresar al menú...", pos_x: @table_start_x, pos_y: return_y, color: :secondary)
#   end

#   defp _wait_for_return_to_menu do
#     _ = IO.gets("")
#     :ok
#   end
# end
