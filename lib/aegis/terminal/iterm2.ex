defmodule Aegis.Terminal.Iterm2 do
  @moduledoc """
  Implementación específica para iTerm2: ventanas, pestañas y paneles.
  """

  # PUBLIC API
  import Argos.Command

  def create_window(_window_id, _opts) do
    script = """
    if application "iTerm2" is running then
      tell application "iTerm2" to create window with default profile
    else
      error "iTerm2 is not running"
    end if
    """
    execute_osascript(script)
  end

  def create_tab(tab_id, command, _opts) do
    script = """
    if application "iTerm2" is running then
      tell application "iTerm2"
        tell current window
          set newTab to create tab with default profile
          tell current session of newTab
            set name to "workspace_#{prepare_string(tab_id)}"
            write text "clear && #{prepare_string(command || "")}"
          end tell
        end tell
      end tell
    else
      error "iTerm2 is not running"
    end if
    """
    execute_osascript(script)
  end

  def create_pane(pane_id, orientation, command, _opts) do
    orientation_cmd = if orientation == :horizontal, do: "create split horizontally with default profile", else: "create split vertically with default profile"
    script = """
    if application "iTerm2" is running then
      tell application "iTerm2"
        #{orientation_cmd}
        tell current session
          write text "clear && #{prepare_string(command || "")}"
          set name to "workspace_#{prepare_string(pane_id)}"
        end tell
      end tell
    else
      error "iTerm2 is not running"
    end if
    """
    execute_osascript(script)
  end

  def send_command(command, opts) do
    if Keyword.has_key?(opts, :tab_id) do
      send_command_to_tab_name(Keyword.get(opts, :tab_id), command)
    else
      send_command_current(command)
    end
  end

  def close_element(opts) do
    if Keyword.has_key?(opts, :tab_id) do
      close_tab_by_name(Keyword.get(opts, :tab_id))
    else
      script = """
      if application "iTerm2" is running then
        tell application "iTerm2"
          tell current session of current window
            close
          end tell
        end tell
      else
        error "iTerm2 is not running"
      end if
      """
      execute_osascript(script)
    end
  end

  def list_elements(type) do
    case type do
      :windows -> list_windows()
      :tabs -> list_tabs()
      :panes -> list_panes()
      :all -> with {:ok, w} <- list_windows(), {:ok, t} <- list_tabs(), {:ok, p} <- list_panes(), do: {:ok, [windows: w, tabs: t, panes: p]}
      _ -> list_windows()
    end
  end

  def resize(height, width) do
    script = """
    if application "iTerm2" is running then
      tell application "iTerm2"
        tell current window
          set bounds to {100, 100, #{height + 100}, #{width + 100}}
        end tell
      end tell
    else
      error "iTerm2 is not running"
    end if
    """
    execute_osascript(script)
  end

  def create_trus_layout(tab_name, services) do
    services
    |> Enum.take(13)
    |> Enum.each(fn svc ->
      create_window(tab_name, [])
      wait_for_session()
      send_command_current(Map.get(svc, :command, ""))
      Process.sleep(150)
    end)

    {:ok, %{layout: "trus_4x4", panes_created: length(services), terminal: :iterm2}}
  end

  def create_trus_services_layout(tab_name, services) do
    services
    |> Enum.take(13)
    |> Enum.each(fn svc ->
      create_window(tab_name, [])
      wait_for_session()
      send_command_current(Map.get(svc, :command, ""))
      Process.sleep(150)
    end)

    {:ok, %{layout: "trus_services", panes_created: length(services), terminal: :iterm2}}
  end

  # PRIVATE HELPERS

  defp execute_osascript(script) do
    tmpfile = Path.join(System.tmp_dir!(), "tmp_iterm2_script.applescript")
    File.write!(tmpfile, script)

    case exec_raw!("osascript -e #{script}", capture_output: true) do
      {output, 0} -> {:ok, String.trim(output)}
      {error, _} -> {:error, String.trim(error)}
    end
  end

  defp prepare_string(str) when is_binary(str), do: str |> String.replace("\\", "\\\\") |> String.replace("\"", "\\\"") |> String.replace("\n", "\\n")
  defp prepare_string(_), do: ""

  defp send_command_current(command) do
    script = """
    if application "iTerm2" is running then
      tell application "iTerm2" to tell current session of current window to write text "#{prepare_string(command)}"
    else
      error "iTerm2 is not running"
    end if
    """
    execute_osascript(script)
  end

  defp send_command_to_tab_name(tab_name, command) do
    case find_tab_by_name_raw(tab_name) do
      {:ok, idx} ->
        script = """
        if application "iTerm2" is running then
          tell application "iTerm2" to tell current window to tell tab #{idx} to tell current session to write text "#{prepare_string(command)}"
        else
          error "iTerm2 is not running"
        end if
        """
        execute_osascript(script)
      {:error, :not_found} -> send_command_current(command)
      error -> error
    end
  end

  defp wait_for_session(), do: Process.sleep(300)

  # Normalizar list outputs
  defp list_windows(), do: execute_osascript("tell application \"iTerm2\" to return name of every window") |> normalize_list()
  defp list_tabs(), do: execute_osascript("tell application \"iTerm2\" to tell current window to return name of every session") |> normalize_list()
  defp list_panes(), do: execute_osascript("tell application \"iTerm2\" to tell current window to return name of every session") |> normalize_list()

  defp normalize_list({:ok, result}) do
    list = result |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
    {:ok, list}
  end
  defp normalize_list(error), do: error

  defp find_tab_by_name_raw(tab_name) do
    case list_tabs() do
      {:ok, tabs} ->
        case Enum.find_index(tabs, &String.contains?(&1, "workspace_#{tab_name}")) do
          nil -> {:error, :not_found}
          idx -> {:ok, idx + 1}  # AppleScript tab index 1-based
        end
      error -> error
    end
  end

  defp close_tab_by_name(tab_name) do
    with {:ok, idx} <- find_tab_by_name_raw(tab_name) do
      script = "tell application \"iTerm2\" to tell current window to close tab #{idx}"
      execute_osascript(script)
    end
  end
end
