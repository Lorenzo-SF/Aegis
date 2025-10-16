# defmodule Aegis.Terminal.Kitty do
#   @moduledoc """
#   Kitty terminal-specific implementations for window, tab, and pane management.

#   Refactor con Argos.Command para centralizar la ejecución de comandos.
#   """

#   @default_shell "/bin/zsh"
#   import Argos.Command

#   # ============================================================================
#   # PUBLIC API
#   # ============================================================================

#   def create_window(opts) do
#     window_id = Keyword.get(opts, :window_id, Keyword.get(opts, :id, "default"))
#     shell = Keyword.get(opts, :shell, @default_shell)
#     kitty_window_id = "KITTY_WINDOW_#{String.upcase(window_id)}"
#     cmd = ["kitty", "@", "launch", "--type=os-window", "--title", kitty_window_id, shell]
#     exec_raw!(cmd, stderr_to_stdout: false)
#   end

#   def create_tab(opts) do
#     tab_id = opts[:tab_id] || "default"
#     command = opts[:command]
#     shell = opts[:shell] || @default_shell
#     kitty_tab_id = "KITTY_TAB_#{String.upcase(tab_id)}"

#     base_cmd = [
#       "kitty",
#       "@",
#       "launch",
#       "--type=tab",
#       "--title",
#       kitty_tab_id,
#       "--cwd",
#       File.cwd!(),
#       shell
#     ]

#     with {:ok, _} <- exec_raw!(base_cmd, stderr_to_stdout: false) do
#       if command do
#         Process.sleep(100)
#         send_command(%{command: command, tab_id: kitty_tab_id})
#       else
#         {:ok, ""}
#       end
#     end
#   end

#   def create_pane(opts) do
#     pane_id = opts[:pane_id] || "default"
#     orientation = opts[:orientation] || :vertical
#     command = opts[:command]
#     shell = opts[:shell] || @default_shell
#     tab_id = opts[:tab_id]

#     location = if orientation == :horizontal, do: "hsplit", else: "vsplit"
#     kitty_pane_id = "KITTY_PANE_#{String.upcase(pane_id)}"

#     base_cmd =
#       ["kitty", "@", "launch", "--type=window", "--location=#{location}", "--title=#{kitty_pane_id}", "--cwd", File.cwd!(), shell]

#     base_cmd =
#       if tab_id do
#         kitty_tab_target =
#           if String.starts_with?(tab_id, "KITTY_TAB_"),
#             do: tab_id,
#             else: "KITTY_TAB_#{String.upcase(tab_id)}"

#         base_cmd ++ ["--match", "title:#{kitty_tab_target}"]
#       else
#         base_cmd
#       end

#     with {:ok, _} <- exec_raw!(base_cmd, stderr_to_stdout: false) do
#       if command do
#         Process.sleep(100)
#         send_command(%{command: command, pane_id: kitty_pane_id})
#       else
#         {:ok, ""}
#       end
#     end
#   end

#   def send_command(opts) do
#     command = opts[:command] || ""
#     # No enviar comando si está vacío
#     if String.trim(command) == "" do
#       {:ok, "No command to send"}
#     else
#       case extract_kitty_target(opts) do
#         nil ->
#           exec_raw!(["kitty", "@", "send-text", "\"#{command}\"\r"], stderr_to_stdout: false)

#         target ->
#           exec_raw!(["kitty", "@", "send-text", "--match", target, "\"#{command}\"\r"], stderr_to_stdout: false)
#       end
#     end
#   end


#   def close_element(opts) do
#     case extract_kitty_target(opts) do
#       nil -> {:error, "No valid target specified"}
#       target ->
#         with {:ok, output} <- exec_raw!(["kitty", "@", "ls", "--format=json"], stderr_to_stdout: true),
#              {:ok, windows_data} <- Jason.decode(output),
#              target_window <- find_target_window(windows_data, target),
#              true <- not is_nil(target_window) do
#           exec_raw!(["kitty", "@", "close-window", "--match", "id:#{target_window["id"]}"], stderr_to_stdout: false)
#         else
#           _ -> {:ok, "No window closed"}
#         end
#     end
#   end

#   def apply_styles(opts) do
#     tab_id = opts[:tab_id]
#     colors = Keyword.get(opts, :colors)

#     if tab_id && colors do
#       fg = Map.get(colors, :foreground, "#FFFFFF")
#       bg = Map.get(colors, :background, "#000000")
#       target = "title:#{tab_id}"
#       exec_raw!(["kitty", "@", "set-colors", "--match", target, "foreground=#{fg}", "background=#{bg}"], stderr_to_stdout: false)
#     else
#       {:ok, "No styles to apply"}
#     end
#   end

#   def apply_layout(opts) do
#     layout = Keyword.get(opts, :layout, "stack")
#     exec_raw!(["kitty", "@", "goto-layout", layout], stderr_to_stdout: false)
#   end

#   def navigate_to(opts) do
#     cond do
#       Keyword.has_key?(opts, :tab_id) ->
#         tab_id = opts[:tab_id]
#         kitty_tab_id = if String.starts_with?(tab_id, "KITTY_TAB_"), do: tab_id, else: "KITTY_TAB_#{String.upcase(tab_id)}"
#         exec_raw!(["kitty", "@", "focus-tab", "--match", "title:#{kitty_tab_id}"], stderr_to_stdout: false)

#       Keyword.has_key?(opts, :window_id) ->
#         window_id = opts[:window_id]
#         kitty_window_id = if String.starts_with?(window_id, "KITTY_WINDOW_"), do: window_id, else: "KITTY_WINDOW_#{String.upcase(window_id)}"
#         exec_raw!(["kitty", "@", "focus-window", "--match", "title:#{kitty_window_id}"], stderr_to_stdout: false)

#       true ->
#         {:error, "No valid target specified"}
#     end
#   end

#   def list_elements(opts \\ %{}) do
#     type = opts[:type] || :all
#     case type do
#       :windows -> exec_raw!(["kitty", "@", "ls", "--format=windows"], stderr_to_stdout: true)
#       :tabs -> exec_raw!(["kitty", "@", "ls", "--format=tabs"], stderr_to_stdout: true)
#       :panes -> exec_raw!(["kitty", "@", "ls", "--format=panes"], stderr_to_stdout: true)
#       _ -> exec_raw!(["kitty", "@", "ls"], stderr_to_stdout: true)
#     end
#   end

#   def find_element(opts) do
#     cond do
#       Keyword.has_key?(opts, :tab_id) ->
#         tab_id = opts[:tab_id]
#         kitty_tab_id = if String.starts_with?(tab_id, "KITTY_TAB_"), do: tab_id, else: "KITTY_TAB_#{String.upcase(tab_id)}"

#         with {:ok, output} <- exec_raw!(["kitty", "@", "ls", "--format=json"], stderr_to_stdout: true),
#              {:ok, windows_data} <- Jason.decode(output) do
#           if Enum.any?(windows_data, fn os_window ->
#                Enum.any?(os_window["tabs"], fn tab ->
#                  Enum.any?(tab["windows"], fn window -> window["title"] == kitty_tab_id end)
#                end)
#              end) do
#             {:ok, %{found: true, name: kitty_tab_id}}
#           else
#             {:error, "Tab not found"}
#           end
#         end

#       Keyword.has_key?(opts, :window_id) ->
#         window_id = opts[:window_id]
#         kitty_window_id = if String.starts_with?(window_id, "KITTY_WINDOW_"), do: window_id, else: "KITTY_WINDOW_#{String.upcase(window_id)}"

#         with {:ok, output} <- exec_raw!(["kitty", "@", "ls", "--format=json"], stderr_to_stdout: true),
#              {:ok, windows_data} <- Jason.decode(output) do
#           if Enum.any?(windows_data, fn os_window -> os_window["title"] == kitty_window_id end) do
#             {:ok, %{found: true, name: kitty_window_id}}
#           else
#             {:error, "Window not found"}
#           end
#         end

#       true ->
#         {:error, "No search criteria specified"}
#     end
#   end

#   def resize(opts) do
#     height = opts[:height] || opts[:rows] || 50
#     width = opts[:width] || opts[:cols] || 80

#     exec_raw!(["kitty", "@", "resize-os-window", "--self", "--width", to_string(width), "--height", to_string(height)], stderr_to_stdout: false)
#     Process.sleep(100)

#     position_script = """
#     tell application "System Events"
#       tell process "kitty"
#         tell window 1
#           set position to {200, 200}
#         end tell
#       end tell
#     end tell
#     """

#     exec_raw!(["osascript", "-e", position_script], stderr_to_stdout: false)
#   end

#   def create_trus_layout(opts) do
#     tab_name = opts[:tab_name] || opts[:tab_id] || "default"
#     services = opts[:services] || []
#     limited_services = Enum.take(services, 13)

#     try do
#       kitty_tab_id =
#         if String.starts_with?(tab_name, "KITTY_TAB_"), do: tab_name, else: "KITTY_TAB_#{String.upcase(tab_name)}"

#       # Layout 4x4
#       create_kitty_window_at_position(kitty_tab_id, "pos_0", "hsplit", nil)
#       create_kitty_window_at_position(kitty_tab_id, "pos_1", "vsplit", "pos_0")
#       create_kitty_window_at_position(kitty_tab_id, "pos_2", "vsplit", "pos_1")
#       create_kitty_window_at_position(kitty_tab_id, "pos_big", "vsplit", "pos_2")
#       create_kitty_window_at_position(kitty_tab_id, "pos_4", "hsplit", "pos_0")
#       create_kitty_window_at_position(kitty_tab_id, "pos_5", "vsplit", "pos_4")
#       create_kitty_window_at_position(kitty_tab_id, "pos_6", "vsplit", "pos_5")
#       create_kitty_window_at_position(kitty_tab_id, "pos_7", "hsplit", "pos_4")
#       create_kitty_window_at_position(kitty_tab_id, "pos_8", "vsplit", "pos_7")
#       create_kitty_window_at_position(kitty_tab_id, "pos_9", "vsplit", "pos_8")
#       create_kitty_window_at_position(kitty_tab_id, "pos_10", "vsplit", "pos_9")
#       create_kitty_window_at_position(kitty_tab_id, "pos_11", "hsplit", "pos_7")
#       create_kitty_window_at_position(kitty_tab_id, "pos_12", "vsplit", "pos_11")
#       create_kitty_window_at_position(kitty_tab_id, "pos_13", "vsplit", "pos_12")
#       create_kitty_window_at_position(kitty_tab_id, "pos_14", "vsplit", "pos_13")

#       assign_services_to_panes_corrected(limited_services)

#       {:ok, %{layout: "trus_4x4", panes_created: length(limited_services), terminal: :kitty}}
#     rescue
#       e -> {:error, "Exception creating kitty layout: #{inspect(e)}"}
#     end
#   end

#   def create_trus_services_layout(opts) do
#     tab_name = opts[:tab_name] || opts[:tab_id] || "default"
#     services = opts[:services] || []
#     limited_services = Enum.take(services, 13)

#     try do
#       kitty_tab_id =
#         if String.starts_with?(tab_name, "KITTY_TAB_"), do: tab_name, else: "KITTY_TAB_#{String.upcase(tab_name)}"

#       # Layout for services
#       create_kitty_window_at_position(kitty_tab_id, "pos_0", "hsplit", nil)
#       create_kitty_window_at_position(kitty_tab_id, "pos_1", "vsplit", "pos_0")
#       create_kitty_window_at_position(kitty_tab_id, "pos_2", "vsplit", "pos_1")
#       create_kitty_window_at_position(kitty_tab_id, "pos_big", "vsplit", "pos_2")
#       create_kitty_window_at_position(kitty_tab_id, "pos_4", "hsplit", "pos_0")
#       create_kitty_window_at_position(kitty_tab_id, "pos_5", "vsplit", "pos_4")
#       create_kitty_window_at_position(kitty_tab_id, "pos_6", "vsplit", "pos_5")
#       create_kitty_window_at_position(kitty_tab_id, "pos_7", "hsplit", "pos_4")
#       create_kitty_window_at_position(kitty_tab_id, "pos_8", "vsplit", "pos_7")
#       create_kitty_window_at_position(kitty_tab_id, "pos_9", "vsplit", "pos_8")
#       create_kitty_window_at_position(kitty_tab_id, "pos_10", "vsplit", "pos_9")
#       create_kitty_window_at_position(kitty_tab_id, "pos_11", "hsplit", "pos_7")
#       create_kitty_window_at_position(kitty_tab_id, "pos_12", "vsplit", "pos_11")
#       create_kitty_window_at_position(kitty_tab_id, "pos_13", "vsplit", "pos_12")
#       create_kitty_window_at_position(kitty_tab_id, "pos_14", "vsplit", "pos_13")

#       assign_services_to_panes_corrected(limited_services)

#       {:ok, %{layout: "trus_services", panes_created: length(limited_services), terminal: :kitty}}
#     rescue
#       e -> {:error, "Exception creating kitty services layout: #{inspect(e)}"}
#     end
#   end

#   # ============================================================================
#   # PRIVATE FUNCTIONS
#   # ============================================================================

#   defp extract_kitty_target(opts) do
#     cond do
#       Keyword.has_key?(opts, :pane_id) ->
#         pane_id = to_string(opts[:pane_id])
#         "title:KITTY_PANE_#{String.upcase(pane_id)}"

#       Keyword.has_key?(opts, :tab_id) ->
#         tab_id = to_string(opts[:tab_id])
#         "title:KITTY_TAB_#{String.upcase(tab_id)}"

#       Keyword.has_key?(opts, :window_id) ->
#         window_id = to_string(opts[:window_id])
#         "title:KITTY_WINDOW_#{String.upcase(window_id)}"

#       true ->
#         nil
#     end
#   end

#   defp create_kitty_window_at_position(tab_id, position_id, location, reference_position) do
#     match_clause =
#       if reference_position, do: ["--match", "title:TRUS_#{reference_position}"], else: ["--match", "title:#{tab_id}"]

#     cmd =
#       ["kitty", "@", "launch", "--type=window", "--location=#{location}", "--title=TRUS_#{position_id}", "--cwd", File.cwd!()] ++ match_clause ++ [@default_shell]

#     exec_raw!(cmd, stderr_to_stdout: false)
#   end

#   defp assign_services_to_panes_corrected(services) do
#     position_titles = [
#       "TRUS_pos_0", "TRUS_pos_1", "TRUS_pos_2", "TRUS_pos_big",
#       "TRUS_pos_4", "TRUS_pos_5", "TRUS_pos_6", "TRUS_pos_7",
#       "TRUS_pos_8", "TRUS_pos_9", "TRUS_pos_10", "TRUS_pos_11", "TRUS_pos_12"
#     ]

#     services
#     |> Enum.take(13)
#     |> Enum.with_index()
#     |> Enum.each(fn {service, index} ->
#       if index < length(position_titles) do
#         title = Enum.at(position_titles, index)
#         command = Map.get(service, :command, Map.get(service, "command", ""))
#         if command != "" do
#           exec_raw!(["kitty", "@", "send-text", "--match", "title:#{title}", "\"#{command}\"\r"], stderr_to_stdout: false)
#           Process.sleep(150)
#         end
#       end
#     end)
#   end

#   defp find_target_window(windows_data, target) do
#     current_window_id = get_current_kitty_window_id()

#     Enum.find_value(windows_data, fn os_window ->
#       Enum.find_value(os_window["tabs"], fn tab ->
#         Enum.find(tab["windows"], fn window ->
#           window_id = to_string(window["id"])
#           is_current = current_window_id && (current_window_id == window_id)
#           matches_target =
#             case target do
#               "title:" <> title -> window["title"] == title
#               "id:" <> id -> window_id == id
#               _ -> window["title"] && String.contains?(target, window["title"])
#             end
#           matches_target && !is_current
#         end)
#       end)
#     end)
#   end

#   defp get_current_kitty_window_id do
#     with {:ok, output} <- exec_raw!(["kitty", "@", "ls", "--format=json"], stderr_to_stdout: true),
#          {:ok, windows_data} <- Jason.decode(output) do
#       Enum.find_value(windows_data, fn os_window ->
#         Enum.find_value(os_window["tabs"], fn tab ->
#           Enum.find_value(tab["windows"], fn window -> if window["is_focused"], do: window["id"], else: nil end)
#         end)
#       end)
#     else
#       _ -> nil
#     end
#   end
# end
