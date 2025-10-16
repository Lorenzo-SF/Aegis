# bash.ex
defmodule Aegis.Terminal.Bash do
  @behaviour Aegis.Terminal.Behaviour

  import Argos.Command

  @impl true
  def create_tab(opts) do
    tab_name = Keyword.get(opts, :name, "default")
    command = Keyword.get(opts, :command)

    cmd = ["tmux", "new-window", "-n", tab_name]

    case exec_raw!(cmd) do
      {:ok, _} ->
        if command do
          send_command(tab_name, command)
        else
          {:ok, "Tab #{tab_name} created"}
        end
      error -> error
    end
  end

  @impl true
  def create_pane(opts) do
    orientation = Keyword.get(opts, :orientation, :vertical)
    target = Keyword.get(opts, :target, "current")
    command = Keyword.get(opts, :command)

    split_flag = if orientation == :vertical, do: "-h", else: "-v"

    cmd = ["tmux", "split-window", split_flag, "-t", target]

    case exec_raw!(cmd) do
      {:ok, _} ->
        if command do
          # El nuevo pane se convierte en el current
          send_command("current", command)
        else
          {:ok, "Pane created"}
        end
      error -> error
    end
  end

  @impl true
  def close_tab(tab_id) do
    cmd = ["tmux", "kill-window", "-t", tab_id]
    case exec_raw!(cmd) do
      {:ok, _} ->
        {:ok, "Tab #{tab_id} closed"}
      error ->
        {:error, "Failed to close tab #{tab_id}: #{inspect(error)}"}
    end
  end

  @impl true
  def close_pane(pane_id) do
    cmd = ["tmux", "kill-pane", "-t", pane_id]
    case exec_raw!(cmd) do
      {:ok, _} ->
        {:ok, "Pane #{pane_id} closed"}
      error ->
        {:error, "Failed to close pane #{pane_id}: #{inspect(error)}"}
    end
  end

  @impl true
  def navigate_to_tab(tab_id) do
    cmd = ["tmux", "select-window", "-t", tab_id]
    case exec_raw!(cmd) do
      {:ok, _} ->
        {:ok, "Navigated to tab #{tab_id}"}
      error ->
        {:error, "Failed to navigate to tab #{tab_id}: #{inspect(error)}"}
    end
  end

  @impl true
  def navigate_to_pane(pane_id) do
    cmd = ["tmux", "select-pane", "-t", pane_id]
    case exec_raw!(cmd) do
      {:ok, _} ->
        {:ok, "Navigated to pane #{pane_id}"}
      error ->
        {:error, "Failed to navigate to pane #{pane_id}: #{inspect(error)}"}
    end
  end

  @impl true
  def send_command(pane_id, command) do
    cmd = ["tmux", "send-keys", "-t", pane_id, command, "C-m"]
    case exec_raw!(cmd) do
      {:ok, _} ->
        {:ok, "Command sent to #{pane_id}"}
      error ->
        {:error, "Failed to send command to #{pane_id}: #{inspect(error)}"}
    end
  end

  @impl true
  def execute_command(pane_id, command) do
    # Similar a send_command pero con mejor manejo de paths
    full_command = "cd #{File.cwd!()} && #{command}"
    send_command(pane_id, full_command)
  end

  @impl true
  def customize_pane(pane_id, colors) do
    fg = Keyword.get(colors, :foreground, "white")
    bg = Keyword.get(colors, :background, "black")

    cmd = [
      "tmux", "select-pane", "-t", pane_id,
      "&&", "tmux", "set-window-option", "window-style", "fg=#{fg},bg=#{bg}"
    ]

    case exec_raw!(["sh", "-c", Enum.join(cmd, " ")]) do
      {:ok, _} ->
        {:ok, "Pane #{pane_id} customized"}
      error ->
        {:error, "Failed to customize pane #{pane_id}: #{inspect(error)}"}
    end
  end

  @impl true
  def create_screen_session(session_name, command, log_file) do
    expanded_log_file = Path.expand(log_file)

    # Crear directorio de logs si no existe
    log_dir = Path.dirname(expanded_log_file)
    File.mkdir_p!(log_dir)

    cmd = [
      "screen",
      "-L",
      "-Logfile", expanded_log_file,
      "-h", "10000",
      "-mdS", session_name,
      "bash", "-c", command
    ]

    case exec_raw!(cmd) do
      {:ok, _} ->
        {:ok, "Screen session #{session_name} started"}
      error ->
        {:error, "Failed to create screen session #{session_name}: #{inspect(error)}"}
    end
  end

  @impl true
  def close_screen_session(session_name) do
    cmd = ["screen", "-X", "-S", session_name, "quit"]
    case exec_raw!(cmd) do
      {:ok, _} ->
        {:ok, "Screen session #{session_name} closed"}
      error ->
        {:error, "Failed to close screen session #{session_name}: #{inspect(error)}"}
    end
  end

  @impl true
  def send_command_to_screen(session_name, command) do
    cmd = ["screen", "-S", session_name, "-X", "stuff", "#{command}\n"]
    case exec_raw!(cmd) do
      {:ok, _} ->
        {:ok, "Command sent to screen session #{session_name}"}
      error ->
        {:error, "Failed to send command to screen session #{session_name}: #{inspect(error)}"}
    end
  end

  @impl true
  def find_screen_session(session_name) do
    cmd = ["screen", "-ls"]
    case exec_raw!(cmd) do
      {:ok, output} ->
        if String.contains?(output, session_name) do
          {:ok, "Screen session #{session_name} found"}
        else
          {:error, "Screen session #{session_name} not found"}
        end
      error -> error
    end
  end

  @impl true
  def apply_layout(layout_spec) do
    rows = Map.get(layout_spec, :rows, 4)
    cols = Map.get(layout_spec, :cols, 4)
    big_panes = Map.get(layout_spec, :big_pane_positions, [])

    # Para layouts complejos, usar select-layout con especificación personalizada
    # Por ahora, aplicación básica de layout tiled
    cmd = ["tmux", "select-layout", "tiled"]

    case exec_raw!(cmd) do
      {:ok, _} ->
        # Aplicar ajustes para panes grandes si se especifican
        apply_big_panes_adjustments(big_panes, rows, cols)
      error -> error
    end
  end

  @impl true
  def create_custom_layout(panes_count, layout_type) do
    case layout_type do
      :grid_4x4 ->
        create_4x4_grid_layout(panes_count)
      :vertical_stack ->
        create_vertical_stack_layout(panes_count)
      :horizontal_split ->
        create_horizontal_split_layout(panes_count)
      _ ->
        {:error, "Unknown layout type: #{layout_type}"}
    end
  end

  @impl true
  def start_application(modules, pane_modules, layout) do
    try do
      # 1. Crear tab nuevo
      {:ok, _} = create_tab(name: "truedat", command: "trus -m")

      # 2. Separar módulos para screen y para panes
      pane_modules_aliases = Enum.map(pane_modules, & &1)

      {screen_modules, pane_modules_list} = Enum.split_with(modules, fn module ->
        not (module.alias in pane_modules_aliases)
      end)

      # 3. Crear screen sessions para módulos en background
      screen_results = Enum.map(screen_modules, fn module ->
        log_file = "~/Desktop/Logs/#{module.alias}.log"
        create_screen_session(Atom.to_string(module.alias), module.script, log_file)
      end)

      # 4. Crear panes para módulos seleccionados
      pane_results = Enum.map(pane_modules_list, fn module ->
        {:ok, _} = create_pane(command: "cd #{module.path} && #{module.script}")
        {:ok, module.alias}
      end)

      # 5. Aplicar layout
      {:ok, _} = apply_layout(layout)

      {:ok, %{
        started: length(modules),
        screen_sessions: length(screen_modules),
        panes: length(pane_modules_list),
        screen_results: screen_results,
        pane_results: pane_results
      }}
    rescue
      e -> {:error, "Failed to start application: #{inspect(e)}"}
    end
  end

  @impl true
  def reindex_application(modules_with_indexes) do
    try do
      # 1. Crear tab nuevo
      {:ok, _} = create_tab(name: "reindex")

      # 2. Para cada módulo+índice, crear pane y ejecutar scripts
      results = Enum.map(modules_with_indexes, fn {module, index} ->
        # Crear pane
        {:ok, _} = create_pane([])

        # Navegar al path y ejecutar scripts
        {:ok, _} = execute_command("current", "cd #{module.path}")
        {:ok, _} = execute_command("current", module.script)
        Process.sleep(1000) # Esperar 1 segundo
        {:ok, _} = execute_command("current", index.script)

        {:ok, %{module: module.alias, index: index.name}}
      end)

      # 3. Aplicar layout automático
      panes_count = length(modules_with_indexes)
      layout_type = if panes_count <= 4, do: :grid_4x4, else: :vertical_stack
      {:ok, _} = create_custom_layout(panes_count, layout_type)

      {:ok, %{
        reindexed: length(modules_with_indexes),
        results: results
      }}
    rescue
      e -> {:error, "Failed to reindex application: #{inspect(e)}"}
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
      # 1. Matar sesión de Tmux actual
      {:ok, _} = exec_raw!(["tmux", "kill-session"])

      # 2. Matar todas las sessions de Screen relacionadas con truedat
      screen_kill_results = kill_all_screen_sessions()

      # 3. Matar procesos específicos
      Process.sleep(500)

      kill_commands = [
        ["pkill", "-f", "tmux"],
        ["pkill", "-f", "screen"],
        ["pkill", "-f", "yarn"],
        ["pkill", "-f", "beam.smp"]
      ]

      kill_results = Enum.map(kill_commands, fn cmd ->
        case exec_raw!(cmd) do
          {:ok, msg} -> {:ok, msg}
          {:error, _} -> {:ok, "Process not running"} # No error si el proceso no existe
        end
      end)

      {:ok, %{
        tmux_killed: true,
        screen_sessions_killed: screen_kill_results,
        processes_killed: kill_results
      }}
    rescue
      e -> {:error, "Failed to kill application: #{inspect(e)}"}
    end
  end

  @impl true
  def terminal_size do
    with {:ok, cols} <- :io.columns(),
      {:ok, rows}<- :io.rows() do
        {rows, cols}
    else
      _ ->
        {80,24}
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
    # For Unix-like systems, use clear command
    case System.cmd("clear", [], stderr_to_stdout: true) do
      {_output, 0} ->
        :ok
      _ ->
        # Fallback: try tput clear
        case System.cmd("tput", ["clear"], stderr_to_stdout: true) do
          {_output, 0} ->
            :ok
          _ ->
            # Last resort: print ANSI escape sequence
            IO.write("\e[H\e[2J")
            :ok
        end
    end
  end

  # Funciones helper privadas
  defp create_4x4_grid_layout(panes_count) do
    # Implementación simplificada - crear grid básico
    cmd = ["tmux", "select-layout", "tiled"]
    case exec_raw!(cmd) do
      {:ok, _} ->
        {:ok, "4x4 grid layout applied"}
      error ->
        {:error, "Failed to apply 4x4 grid layout: #{inspect(error)}"}
    end
  end

  defp create_vertical_stack_layout(panes_count) do
    # Crear stack vertical de panes
    Enum.each(1..(panes_count-1), fn _ ->
      create_pane(orientation: :horizontal)
    end)
    {:ok, %{layout: :vertical_stack, panes: panes_count}}
  end

  defp create_horizontal_split_layout(panes_count) do
    # Crear split horizontal de panes
    Enum.each(1..(panes_count-1), fn _ ->
      create_pane(orientation: :vertical)
    end)
    {:ok, %{layout: :horizontal_split, panes: panes_count}}
  end

  defp apply_big_panes_adjustments(big_panes, rows, cols) do
    # Para cada posición de pane grande, ajustar tamaño
    Enum.each(big_panes, fn {row, col} ->
      # Lógica para fusionar panes en tmux
      # Esto es una simplificación - implementación real sería más compleja
      pane_id = "#{row}.#{col}"
      cmd = ["tmux", "resize-pane", "-t", pane_id, "-x", "2", "-y", "2"]
      exec_raw!(cmd)
    end)
    {:ok, "Big panes adjustments applied"}
  end

  defp kill_all_screen_sessions() do
    case exec_raw!(["screen", "-ls"]) do
      {:ok, output} ->
        sessions = extract_screen_sessions(output)
        Enum.map(sessions, fn session ->
          close_screen_session(session)
        end)
      _ -> []
    end
  end

  defp extract_screen_sessions(output) do
    Regex.scan(~r/\d+\.(\S+)/, output)
    |> Enum.map(fn [_, session] -> session end)
    |> Enum.filter(&String.contains?(&1, "truedat"))
  end

  @impl true
  def close_element(element_id) do
    # For Bash/Tmux implementation, try to close as tab first, then as pane
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
