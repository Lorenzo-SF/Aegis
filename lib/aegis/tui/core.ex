defmodule Aegis.Tui.Core do
  @moduledoc """
  Bucle principal del TUI.

  Maneja el bucle de entrada, renderizado y ejecución de acciones.
  """

  require Logger
  alias Aegis.Tui.{Terminal, Renderer, InputHandler, MenuBuilder}

  @doc """
  Ejecuta el bucle principal del TUI.
  """
  def run_tui_loop(state) do
    Terminal.clear_from_cursor()
    Renderer.render_menu(state)
    input_loop(state)
  end

  @doc """
  Bucle de entrada principal.
  """
  def input_loop(state) do
    case InputHandler.read_raw_char() do
      {:ok, char_sequence} ->
        case InputHandler.handle_key(state, char_sequence) do
          {:continue, new_state} ->
            Renderer.render_cursor_update(state, new_state)
            input_loop(new_state)

          {:update_search, new_state} ->
            redraw_menu(new_state)
            input_loop(new_state)

          {:execute, option} ->
            handle_option_execution(state, option)

          {:exit, result} ->
            result
        end

      {:error, _reason} ->
        input_loop(state)
    end
  end

  @doc """
  Maneja la ejecución de una opción seleccionada.
  """
  def handle_option_execution(state, option) do
    case option.action_type do
      :navigation -> handle_navigation(state, option)
      :execution -> handle_execution(state, option)
    end
  end

  # Privadas

  defp handle_navigation(state, option) do
    case MenuBuilder.execute_option_action(state, option) do
      {:navigate, new_state} ->
        redraw_menu(new_state)
        input_loop(new_state)

      {:error, message} ->
        Logger.error("Error navegando: #{message}")
        pause_and_redraw(state)
        input_loop(state)
    end
  end

  defp handle_execution(state, option) do
    exit_raw_mode()
    result =
      try do
        MenuBuilder.execute_option_action(state, option)
      rescue
        error -> {:error, error}
      end

    case result do
      {:navigate, new_state} ->
        pause_and_redraw(new_state)

      {:error, error} ->
        IO.puts("Error ejecutando acción: #{Exception.message(error)}")
        pause_and_redraw(state)

      _ ->
        pause_and_redraw(state)
    end

    input_loop(state)
  end

  defp exit_raw_mode do
    Terminal.cleanup_raw_terminal()
    IO.write("\e[2J\e[H")
  end

  defp pause_and_redraw(state) do
    IO.puts("\nPresiona Enter para continuar...")
    IO.gets("")
    Terminal.init_raw_terminal()
    redraw_menu(state)
  end

  defp redraw_menu(state) do
    Terminal.clear_from_cursor()
    Renderer.render_menu(state)
  end
end
