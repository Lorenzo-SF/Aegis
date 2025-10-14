defmodule Aegis.Terminal.Tmux do
  @moduledoc """
  Tmux terminal-specific implementations for window, tab, and pane management.

  This module provides all Tmux terminal functionality for creating, managing,
  and controlling terminal windows, tabs, and panes.
  """
  import Argos.Command

  # ============================================================================
  # PUBLIC API
  # ============================================================================

  def create_window(window_id, _opts) do
    execute_tmux(["new-window", "-n", window_id])
  end

  def create_tab(tab_id, command, _opts) do
    with {:ok, _} <- execute_tmux(["new-window", "-n", tab_id]) do
      if command do
        execute_tmux(["send-keys", "-t", tab_id, command, "C-m"])
      else
        {:ok, tab_id}
      end
    end
  end

  def create_pane(pane_id, orientation, command, _opts) do
    split_flag = if orientation == :vertical, do: "-h", else: "-v"

    with {:ok, _} <- execute_tmux(["split-window", split_flag]) do
      if command do
        execute_tmux(["send-keys", command, "C-m"])
      else
        {:ok, pane_id}
      end
    end
  end

  def send_command(command, opts) do
    case extract_tmux_target(opts) do
      nil -> {:error, "No target specified for send_command"}
      target -> execute_tmux(["send-keys", "-t", target, command, "C-m"])
    end
  end

  def close_element(opts) do
    cond do
      Keyword.has_key?(opts, :pane_id) ->
        execute_tmux(["kill-pane"])

      Keyword.has_key?(opts, :tab_id) ->
        execute_tmux(["kill-window", "-t", opts[:tab_id]])

      Keyword.has_key?(opts, :window_id) ->
        execute_tmux(["kill-window", "-t", opts[:window_id]])

      true ->
        {:error, "No valid target specified"}
    end
  end

  def apply_styles(opts) do
    tab_id = Keyword.get(opts, :tab_id)
    colors = Keyword.get(opts, :colors)

    if tab_id && colors do
      fg = Map.get(colors, :foreground, "#FFFFFF")
      bg = Map.get(colors, :background, "#000000")

      with {:ok, _} <- execute_tmux(["select-window", "-t", tab_id]),
           {:ok, _} <-
             execute_tmux([
               "set-window-option",
               "-t",
               tab_id,
               "window-style",
               "fg=#{fg},bg=#{bg}"
             ]) do
        {:ok, "Styles applied"}
      end
    else
      {:ok, "No styles to apply"}
    end
  end

  def apply_layout(opts) do
    layout = Keyword.get(opts, :layout, "tiled")
    execute_tmux(["select-layout", layout])
  end

  def navigate_to(opts) do
    cond do
      Keyword.has_key?(opts, :tab_id) ->
        execute_tmux(["select-window", "-t", opts[:tab_id]])

      Keyword.has_key?(opts, :pane_id) ->
        execute_tmux(["select-pane", "-t", opts[:pane_id]])

      true ->
        {:error, "No valid target specified"}
    end
  end

  def list_elements(type) do
    case type do
      :windows ->
        execute_tmux(["list-windows"])

      :panes ->
        execute_tmux(["list-panes"])

      :all ->
        windows_result = execute_tmux(["list-windows"])
        panes_result = execute_tmux(["list-panes"])

        case {windows_result, panes_result} do
          {{:ok, windows}, {:ok, panes}} -> {:ok, [windows: windows, panes: panes]}
          _ -> {:error, "Could not retrieve windows and panes"}
        end

      _ ->
        execute_tmux(["list-windows"])
    end
  end

  def find_element(opts) do
    cond do
      Keyword.has_key?(opts, :tab_id) ->
        with {:ok, output} <- execute_tmux(["list-windows", "-F", "\#{window_name}"]) do
          if String.contains?(output, opts[:tab_id]) do
            {:ok, %{found: true, name: opts[:tab_id]}}
          else
            {:error, "Tab not found"}
          end
        end

      Keyword.has_key?(opts, :window_id) ->
        with {:ok, output} <- execute_tmux(["list-windows", "-F", "\#{window_name}"]) do
          if String.contains?(output, opts[:window_id]) do
            {:ok, %{found: true, name: opts[:window_id]}}
          else
            {:error, "Window not found"}
          end
        end

      true ->
        {:error, "No search criteria specified"}
    end
  end

  def resize(rows) do
    execute_tmux(["resize-window", "-y", to_string(rows)])
  end

  def create_trus_layout(tab_name, services) do
    limited_services = Enum.take(services, 13)

    try do
      execute_tmux(["select-window", "-t", tab_name])

      # Paso 1: Crear filas principales
      execute_tmux(["split-window", "-v", "-p", "25"])
      execute_tmux(["split-window", "-v", "-p", "33"])
      execute_tmux(["split-window", "-v", "-p", "50"])

      # Paso 2: Dividir fila 1 en 4 columnas
      execute_tmux(["select-pane", "-t", "0"])
      execute_tmux(["split-window", "-h", "-p", "75"])
      execute_tmux(["split-window", "-h", "-p", "67"])
      execute_tmux(["split-window", "-h", "-p", "50"])

      # Paso 3: Dividir fila 2 en 3 columnas
      execute_tmux(["select-pane", "-t", "4"])
      execute_tmux(["split-window", "-h", "-p", "67"])
      execute_tmux(["split-window", "-h", "-p", "50"])

      # Paso 4: Fusionar pane grande
      execute_tmux(["join-pane", "-v", "-s", "7", "-t", "3"])

      # Paso 5: Dividir fila 3 en 4 columnas
      execute_tmux(["select-pane", "-t", "6"])
      execute_tmux(["split-window", "-h", "-p", "75"])
      execute_tmux(["split-window", "-h", "-p", "67"])
      execute_tmux(["split-window", "-h", "-p", "50"])

      # Paso 6: Dividir fila 4 en 4 columnas
      execute_tmux(["select-pane", "-t", "10"])
      execute_tmux(["split-window", "-h", "-p", "75"])
      execute_tmux(["split-window", "-h", "-p", "67"])
      execute_tmux(["split-window", "-h", "-p", "50"])

      # Paso 7: Asignar comandos
      assign_services_to_panes_corrected(tab_name, limited_services)

      {:ok, %{layout: "trus_4x4", panes_created: length(limited_services), terminal: :tmux}}
    rescue
      e -> {:error, "Exception creating tmux layout: #{inspect(e)}"}
    end
  end

  def create_trus_services_layout(tab_name, services) do
    limited_services = Enum.take(services, 13)

    try do
      execute_tmux(["select-window", "-t", tab_name])

      # Create main rows
      execute_tmux(["split-window", "-v", "-p", "25"])
      execute_tmux(["split-window", "-v", "-p", "33"])
      execute_tmux(["split-window", "-v", "-p", "50"])

      # Split row 1 into 4 columns
      execute_tmux(["select-pane", "-t", "0"])
      execute_tmux(["split-window", "-h", "-p", "75"])
      execute_tmux(["split-window", "-h", "-p", "67"])
      execute_tmux(["split-window", "-h", "-p", "50"])

      # Split row 2 into 3 columns
      execute_tmux(["select-pane", "-t", "4"])
      execute_tmux(["split-window", "-h", "-p", "67"])
      execute_tmux(["split-window", "-h", "-p", "50"])

      # Merge big pane
      execute_tmux(["join-pane", "-v", "-s", "7", "-t", "3"])

      # Split row 3 into 4 columns
      execute_tmux(["select-pane", "-t", "6"])
      execute_tmux(["split-window", "-h", "-p", "75"])
      execute_tmux(["split-window", "-h", "-p", "67"])
      execute_tmux(["split-window", "-h", "-p", "50"])

      # Split row 4 into 4 columns
      execute_tmux(["select-pane", "-t", "10"])
      execute_tmux(["split-window", "-h", "-p", "75"])
      execute_tmux(["split-window", "-h", "-p", "67"])
      execute_tmux(["split-window", "-h", "-p", "50"])

      # Assign commands
      assign_services_to_panes_corrected(tab_name, limited_services)

      {:ok, %{layout: "trus_services", panes_created: length(limited_services), terminal: :tmux}}
    rescue
      e -> {:error, "Exception creating tmux services layout: #{inspect(e)}"}
    end
  end

  # ============================================================================
  # PRIVATE FUNCTIONS
  # ============================================================================

  defp extract_tmux_target(opts) do
    cond do
      Keyword.has_key?(opts, :tab_id) -> opts[:tab_id]
      Keyword.has_key?(opts, :window_id) -> opts[:window_id]
      true -> nil
    end
  end

  defp assign_services_to_panes_corrected(tab_name, services) do
    pane_mapping = 0..12 |> Enum.to_list()

    services
    |> Enum.take(13)
    |> Enum.with_index()
    |> Enum.each(fn {service, index} ->
      if index < length(pane_mapping) do
        pane_number = Enum.at(pane_mapping, index)
        pane_id = "#{tab_name}.#{pane_number}"
        command = Map.get(service, :command, Map.get(service, "command", ""))

        if command != "" do
          execute_tmux(["send-keys", "-t", pane_id, command, "C-m"])
          Process.sleep(150)
        end
      end
    end)
  end

  defp execute_tmux(args, opts \\ [capture_output: true]) do
    exec_raw!(["tmux" | args], opts)
  end
end
