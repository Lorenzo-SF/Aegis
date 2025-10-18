defmodule Aegis.Terminal do
  @moduledoc """
  Módulo principal para gestión de terminal usando Bash y tmux.
  Proporciona funcionalidades de gestión de terminal para entornos Unix-like,
  incluyendo la gestión de panes, sesiones de screen y comandos tmux.
  """

  require Logger
  import Argos.Command

  # ======================
  # Gestión de Sesiones Tmux
  # ======================

  @doc """
  Verifica si existe una sesión tmux
  """
  def has_session?(session_name) do
    case exec_raw!("tmux has-session -t #{to_string(session_name)}", stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end

  @doc """
  Crea una nueva sesión tmux
  """
  def new_tmux_session(session_name) do
    case exec_raw!("tmux new-session -d -s #{to_string(session_name)}", stderr_to_stdout: true) do
      {_, 0} ->
        {:ok, session_name}

      {error_output, _} ->
        {:error, "Failed to create tmux session: #{error_output}"}
    end
  end

  @doc """
  Mata una sesión tmux específica si existe
  """
  def kill_tmux_session(session_name) do
    if has_session?(session_name) do
      case exec_raw!("tmux kill-session -t #{session_name}", stderr_to_stdout: true) do
        {_output, 0} ->
          {:ok, session_name}
        {error_output, _} ->
          {:error, "Failed to kill tmux session: #{error_output}"}
      end
    else
      {:ok, session_name} # No existe, nada que hacer
    end
  end

  @doc """
  Cuenta el número de panes en una sesión
  """
  def count_panes(session) do
    case exec_raw!("tmux list-panes -t #{session}", stderr_to_stdout: true) do
      {output, 0} ->
        count = output |> String.split("\n", trim: true) |> length()
        {:ok, count}

      {error_output, _} ->
        {:error, "Failed to count panes: #{error_output}"}
    end
  end

  # ======================
  # Gestión de Panes
  # ======================

  @doc """
  Crea un nuevo pane en la sesión actual
  """
  def create_pane(opts) do
    orientation = Keyword.get(opts, :orientation, :vertical)
    target = Keyword.get(opts, :target, "current")
    command = Keyword.get(opts, :command)

    split_flag = if orientation == :vertical, do: "-h", else: "-v"

    case exec_raw!("tmux split-window #{split_flag} -t #{target}", stderr_to_stdout: true) do
      {_, 0} ->
        if command do
          # El nuevo pane se convierte en el current
          send_command("current", command)
        else
          {:ok, "Pane created"}
        end

      {error_output, _} ->
        {:error, "Failed to create pane: #{error_output}"}
    end
  end

  @doc """
  Crea un pane vertical en una sesión específica
  """
  def split_window_vertical(session, target_pane \\ "0") do
    target = "#{session}:0.#{target_pane}"
    case exec_raw!("tmux split-window -v -t #{target}", stderr_to_stdout: true) do
      {_, 0} ->
        {:ok, session}

      {error_output, _} ->
        {:error, "Failed to create vertical pane: #{error_output}"}
    end
  end

  @doc """
  Crea un pane vertical y ejecuta un script en él
  """
  def create_pane_and_execute_script(session_name, script) do
    case split_window_vertical(session_name, "0") do
      {:ok, ^session_name} ->
        case send_command_to_pane({:ok, session_name}, "1", script) do
          {:ok, ^session_name} ->
            {:ok, session_name}
          {:error, error} ->
            {:error, "Error ejecutando script en pane: #{error}"}
        end
      {:error, error} ->
        {:error, "Error creando pane: #{error}"}
    end
  end

  @doc """
  Envía comando a un pane específico
  """
  def send_command(pane_id, command) do
    case exec_raw!("tmux send-keys -t #{to_string(pane_id)} '#{to_string(command)}' C-m", stderr_to_stdout: true) do
      {_, 0} ->
        {:ok, "Command sent to #{pane_id}"}

      {error_output, _} ->
        {:error, "Failed to send command to #{pane_id}: #{error_output}"}
    end
  end

  @doc """
  Envía comando a un pane específico de una sesión usando targeting preciso
  """
  def send_command_to_pane({:error, target}, pane, command) do
    Logger.error("Error intentando ejecutar un comando en Tmux: \nSesion: #{target}\nPane: #{pane}\nCommand: #{command}")
  end

  def send_command_to_pane({:ok, session}, pane, command) do
    target = "#{session}:0.#{pane}"
    case exec_raw!("tmux send-keys -t #{target} '#{to_string(command)}' C-m", stderr_to_stdout: true) do
      {_, 0} ->
        {:ok, session}

      {error_output, _} ->
        {:error, "Failed to send command to #{target}: #{error_output}"}
    end
  end

  @doc """
  Envía comando a la ventana principal de una sesión
  """
  def send_command_to_session(session, command) do
    target = "#{session}:0"
    case exec_raw!("tmux send-keys -t #{target} '#{to_string(command)}' C-m", stderr_to_stdout: true) do
      {_, 0} -> {:ok, session}

      {error_output, _} ->
        {:error, "Failed to send command to #{target}: #{error_output}"}
    end
  end

  @doc """
  Aplica un layout a los panes
  """
  def apply_layout(layout_spec) do
    # Por ahora, aplicación básica de layout tiled
    case exec_raw!("tmux select-layout tiled", stderr_to_stdout: true) do
      {_, 0} ->
        {:ok, "Layout applied"}

      {error_output, _} ->
        {:error, error_output}
    end
  end

  @doc """
  Cierra un elemento (tab o pane)
  """
  def close_element(element_id) do
    # Primero intentar cerrar como tab
    case exec_raw!("tmux kill-window -t #{to_string(element_id)}", stderr_to_stdout: true) do
      {_, 0} ->
        {:ok, "Element #{element_id} closed as tab"}

      {_error_output, _} ->
        # Si falla, intentar cerrar como pane
        case exec_raw!("tmux kill-pane -t #{to_string(element_id)}", stderr_to_stdout: true) do
          {_, 0} ->
            {:ok, "Element #{element_id} closed as pane"}

          {error_output, _} ->
            {:error, "Failed to close element #{element_id}: #{error_output}"}
        end
    end
  end

  # ======================
  # Gestión de Screen Sessions
  # ======================

  @doc """
  Crea una sesión de screen con logging
  """
  def create_screen_session(session_name, command, log_file) do
    expanded_log_file = Path.expand(log_file)

    # Crear directorio de logs si no existe
    log_dir = Path.dirname(expanded_log_file)
    File.mkdir_p!(log_dir)

    case exec_raw!("screen -L -Logfile #{expanded_log_file} -h 10000 -mdS #{to_string(session_name)} bash -c '#{to_string(command)}'", stderr_to_stdout: true) do
      {_, 0} ->
        {:ok, "Screen session #{session_name} started"}

      {error_output, _} ->
        {:error, "Failed to create screen session #{session_name}: #{error_output}"}
    end
  end

  @doc """
  Busca una sesión de screen específica
  """
  def find_screen_session(session_name) do
    case exec_raw!("screen -ls", stderr_to_stdout: true) do
      {output, 0} ->
        if String.contains?(output, session_name) do
          {:ok, "Screen session #{session_name} found"}
        else
          {:error, "Screen session #{session_name} not found"}
        end

      {error_output, _} ->
        {:error, error_output}
    end
  end

  @doc """
  Lista todas las sesiones de screen activas
  """
  def list_screen_sessions do
    case exec_raw!("screen -ls", stderr_to_stdout: true) do
      {output, _} ->
        sessions = parse_screen_sessions(output)
        {:ok, sessions}
    end
  end

  @doc """
  Mata todas las sesiones de screen
  """
  def kill_screen_sessions do
    case exec_raw!("screen -ls", stderr_to_stdout: true) do
      {output, _} ->
        sessions = extract_screen_sessions(output)

        Enum.map(sessions, fn session ->
          exec_raw!("screen -X -S #{to_string(session)} quit", stderr_to_stdout: true)
        end)
    end
  end

  # ======================
  # Utilidades
  # ======================
  def size do
    with {:ok, cols} <- :io.columns(),
         {:ok, rows} <- :io.rows() do
      {cols, rows}
    else
      _ ->
        {80, 24}
    end
  end

  def width do
    elem(size(), 0)
  end

  def height do
    elem(size(), 1)
  end

  @doc """
  Limpia la pantalla del terminal
  """
  def clear_screen do
    case exec_raw!("clear", stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      _ ->
        # Fallback: usar ANSI escape sequence
        IO.write("\e[H\e[2J")
        :ok
    end
  end

  # ======================
  # Funciones Helper Privadas
  # ======================

  defp parse_screen_sessions(output) do
    Regex.scan(~r/(\d+)\.(\S+)\s+\(([^)]+)\)/, output)
    |> Enum.map(fn [_, id, name, status] ->
      %{
        id: id,
        name: name,
        status: String.trim(status),
        full_name: "#{id}.#{name}"
      }
    end)
  end

  defp extract_screen_sessions(output) do
    Regex.scan(~r/\d+\.(\S+)/, output)
    |> Enum.map(fn [_, session] -> session end)
    |> Enum.filter(&String.contains?(&1, "truedat"))
  end
end
