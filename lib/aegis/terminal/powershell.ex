# powershell.ex
defmodule Aegis.Terminal.PowerShell do
  @behaviour Aegis.Terminal.Behaviour

  import Argos.Command

  @impl true
  def create_tab(opts) do
    tab_name = Keyword.get(opts, :name, "default")
    command = Keyword.get(opts, :command)

    # Usar Windows Terminal si está disponible
    if windows_terminal_available?() do
      create_windows_terminal_tab(tab_name, command)
    else
      create_powershell_tab(tab_name, command)
    end
  end

  @impl true
  def create_pane(opts) do
    # En Windows, la creación de panes es más limitada
    # Usar Windows Terminal panes o crear nuevas ventanas
    if windows_terminal_available?() do
      create_windows_terminal_pane(opts)
    else
      {:error, "Pane creation not supported in basic PowerShell"}
    end
  end

  @impl true
  def close_tab(tab_id) do
    # En Windows, cerrar pestaña/pane
    cmd = ["taskkill", "/f", "/im", "wt.exe"]
    case exec_raw!(cmd) do
      {:ok, _} ->
        {:ok, "Tab closed"}
      error ->
        {:error, "Failed to close tab: #{inspect(error)}"}
    end
  end

  @impl true
  def close_pane(pane_id) do
    # Similar a close_tab en Windows
    close_tab(pane_id)
  end

  @impl true
  def navigate_to_tab(tab_id) do
    # Navegación limitada en Windows
    {:ok, "Navigate to tab not fully supported in Windows"}
  end

  @impl true
  def navigate_to_pane(pane_id) do
    {:ok, "Navigate to pane not fully supported in Windows"}
  end

  @impl true
  def send_command(pane_id, command) do
    # Enviar comando usando PowerShell
    ps_command = "Start-Process powershell -ArgumentList '-Command \"#{command}\"'"
    exec_raw!(["powershell", "-Command", ps_command])
  end

  @impl true
  def execute_command(pane_id, command) do
    full_command = "cd #{File.cwd!()}; #{command}"
    send_command(pane_id, full_command)
  end

  @impl true
  def customize_pane(pane_id, colors) do
    # Personalización limitada en Windows
    {:ok, "Pane customization not supported in Windows"}
  end

  @impl true
  def create_screen_session(session_name, command, log_file) do
    # En Windows, usar Start-Process en background
    log_dir = Path.dirname(log_file)
    File.mkdir_p!(log_dir)

    ps_command = """
    Start-Process powershell -ArgumentList '-Command \"#{command}\"' \
    -WindowStyle Hidden \
    -RedirectStandardOutput \"#{log_file}\" \
    -RedirectStandardError \"#{log_file}.error\"
    """

    case exec_raw!(["powershell", "-Command", ps_command]) do
      {:ok, _} ->
        {:ok, "Background process started for #{session_name}"}
      error ->
        {:error, "Failed to start background process for #{session_name}: #{inspect(error)}"}
    end
  end

  @impl true
  def close_screen_session(session_name) do
    # Matar proceso por nombre
    ps_command = "Get-Process | Where-Object {$_.ProcessName -like '*#{session_name}*'} | Stop-Process -Force"
    case exec_raw!(["powershell", "-Command", ps_command]) do
      {:ok, _} ->
        {:ok, "Background process #{session_name} stopped"}
      error ->
        {:error, "Failed to stop background process #{session_name}: #{inspect(error)}"}
    end
  end

  @impl true
  def send_command_to_screen(session_name, command) do
    # No directamente soportado en Windows
    {:error, "Send command to background process not supported in Windows"}
  end

  @impl true
  def find_screen_session(session_name) do
    ps_command = "Get-Process | Where-Object {$_.ProcessName -like '*#{session_name}*'}"
    case exec_raw!(["powershell", "-Command", ps_command]) do
      {:ok, output} ->
        if String.trim(output) != "", do: {:ok, "Process found"}, else: {:error, "Process not found"}
      error -> error
    end
  end

  @impl true
  def apply_layout(layout_spec) do
    # Layouts complejos no soportados en Windows básico
    {:ok, "Layout application limited in Windows"}
  end

  @impl true
  def create_custom_layout(panes_count, layout_type) do
    {:ok, %{layout: layout_type, panes: panes_count, note: "Layout visualization limited in Windows"}}
  end

  @impl true
  def start_application(modules, pane_modules, layout) do
    try do
      # En Windows, enfoque simplificado
      {:ok, _} = create_tab(name: "truedat", command: "trus -m")

      pane_modules_aliases = Enum.map(pane_modules, & &1)

      # Iniciar todos los módulos en background o nuevas pestañas
      results = Enum.map(modules, fn module ->
        if module.alias in pane_modules_aliases do
          # Crear nueva pestaña para módulo visible
          create_tab(name: Atom.to_string(module.alias), command: "cd #{module.path} && #{module.script}")
        else
          # Ejecutar en background
          log_file = "~/Desktop/Logs/#{module.alias}.log"
          create_screen_session(Atom.to_string(module.alias), module.script, log_file)
        end
      end)

      {:ok, %{
        started: length(modules),
        results: results,
        note: "Windows implementation uses separate tabs for visible modules"
      }}
    rescue
      e -> {:error, "Failed to start application in Windows: #{inspect(e)}"}
    end
  end

  @impl true
  def reindex_application(modules_with_indexes) do
    try do
      # En Windows, crear pestaña separada para cada reindexado
      results = Enum.map(modules_with_indexes, fn {module, index} ->
        tab_name = "reindex-#{module.alias}-#{index.name}"
        commands = [
          "cd #{module.path}",
          module.script,
          "Timeout /T 1", # Esperar 1 segundo
          index.script
        ]
        full_command = Enum.join(commands, " && ")
        create_tab(name: tab_name, command: full_command)
      end)

      {:ok, %{
        reindexed: length(modules_with_indexes),
        results: results
      }}
    rescue
      e -> {:error, "Failed to reindex application in Windows: #{inspect(e)}"}
    end
  end

  @impl true
  def open_pod_terminal(context, pod_name) do
    command = "kubectl exec -it --context=#{context} #{pod_name} -- /bin/bash"
    create_tab(name: "pod-#{pod_name}", command: command)
  end

  @impl true
  def kill_application() do
    try do
      # Matar procesos relacionados con truedat
      kill_commands = [
        ["taskkill", "/f", "/im", "wt.exe"],
        ["taskkill", "/f", "/im", "powershell.exe"],
        ["taskkill", "/f", "/im", "node.exe"],
        ["taskkill", "/f", "/im", "beam.exe"]
      ]

      kill_results = Enum.map(kill_commands, fn cmd ->
        case exec_raw!(cmd) do
          {:ok, msg} -> {:ok, msg}
          {:error, _} -> {:ok, "Process not running"}
        end
      end)

      {:ok, %{
        processes_killed: kill_results,
        note: "Windows process termination completed"
      }}
    rescue
      e -> {:error, "Failed to kill application in Windows: #{inspect(e)}"}
    end
  end

  @impl true
  def terminal_size do
    # For Windows, try to get terminal size using PowerShell
    case System.cmd("powershell", ["-Command", "(Get-Host).UI.RawUI.WindowSize.Width; (Get-Host).UI.RawUI.WindowSize.Height"], stderr_to_stdout: true) do
      {output, 0} ->
        [width, height] = output |> String.split() |> Enum.map(&String.to_integer/1)
        {width, height}
      _ ->
        {380, 24}  # Default fallback
    end
  end

  @impl true
  def terminal_width(size \\ nil) do
    case size do
      nil ->
        {width, _height} = terminal_size()
        width
      _ ->
        size
    end
  end

  @impl true
  def clear_screen do
    # For Windows, use cls command
    case System.cmd("cls", [], stderr_to_stdout: true) do
      {_output, 0} ->
        :ok
      _ ->
        # Fallback: print ANSI escape sequence
        IO.write("\e[H\e[2J")
        :ok
    end
  end

  # Helpers específicos de Windows
  defp windows_terminal_available? do
    case exec_raw!(["where", "wt"]) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp create_windows_terminal_tab(tab_name, command) do
    cmd =
      if command do
        ["wt", "--title", tab_name, "powershell", "-Command", command]
      else
        ["wt", "--title", tab_name]
      end

    case exec_raw!(cmd) do
      {:ok, _} ->
        {:ok, "Windows Terminal tab #{tab_name} created"}
      error ->
        {:error, "Failed to create Windows Terminal tab: #{inspect(error)}"}
    end
  end

  defp create_powershell_tab(tab_name, command) do
    cmd =
      if command do
        ["start", "powershell", "-NoExit", "-Command", command]
      else
        ["start", "powershell", "-NoExit"]
      end

    case exec_raw!(cmd) do
      {:ok, _} ->
        {:ok, "PowerShell tab #{tab_name} created"}
      error ->
        {:error, "Failed to create PowerShell tab: #{inspect(error)}"}
    end
  end

  defp create_windows_terminal_pane(opts) do
    orientation = Keyword.get(opts, :orientation, :vertical)
    command = Keyword.get(opts, :command)

    split_flag = if orientation == :vertical, do: "--vertical", else: "--horizontal"

    base_cmd = ["wt", split_flag]
    cmd = if command, do: base_cmd ++ ["powershell", "-Command", command], else: base_cmd

    case exec_raw!(cmd) do
      {:ok, _} ->
        {:ok, "Windows Terminal pane created"}
      error ->
        {:error, "Failed to create Windows Terminal pane: #{inspect(error)}"}
    end
  end

  @impl true
  def close_element(element_id) do
    # For PowerShell/Windows Terminal, try to close as tab first, then as pane
    case close_tab(element_id) do
      {:ok, _} ->
        {:ok, "Element #{element_id} closed as tab"}
      {:error, _} ->
        # If tab closing fails, try as pane
        case close_pane(element_id) do
          {:ok, _} ->
            {:ok, "Element #{element_id} closed as pane"}
          error ->
            error
        end
    end
  end

end
