defmodule Aegis.Tui.Core do
  @moduledoc """
  Bucle principal del TUI.

  Maneja el bucle de entrada, renderizado y ejecución de acciones.
  """

  require Logger
  alias Aegis.Tui
  alias Aegis.Tui.{Renderer, InputHandler, MenuBuilder}

  @doc """
  Starts the TUI with provided options.
  """
  def start_tui(options) when is_list(options) do
    # Convert simple string options to menu options
    menu_options =
      Enum.with_index(options, 1)
      |> Enum.map(fn {option, index} ->
        %{
          id: index,
          name: option,
          description: option,
          action_type: :execution,
          action: {:execute, option}
        }
      end)

    initial_state = %{
      menu_info: %{
        breadcrumbs: ["Main Menu"],
        options: menu_options,
        multiselect: false
      },
      filtered_options: menu_options,
      cursor_index: 0,
      selected_indices: MapSet.new(),
      search_term: ""
    }

    Tui.with_terminal(fn ->
      run_tui_loop(initial_state)
    end)
  end

  @doc """
  Ejecuta el bucle principal del TUI.
  """
  def run_tui_loop(state) do
    Tui.clear_from_cursor()
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

          {:exit, :cancelled} ->
            # Salir directamente de la aplicación al presionar ESC
            Tui.cleanup_raw_terminal()
            System.halt(0)

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
        IO.puts(inspect(option))
        pause_and_redraw(state)

      _ ->
        pause_and_redraw(state)
    end

    input_loop(state)
  end

  defp exit_raw_mode do
    Tui.cleanup_raw_terminal()
    IO.write("\e[2J\e[H")
  end

  defp pause_and_redraw(state) do
    IO.puts("\nPresiona Enter para continuar...")
    IO.gets("")
    Tui.init_raw_terminal()
    redraw_menu(state)
  end

  defp redraw_menu(state) do
    Tui.clear_from_cursor()
    Renderer.render_menu(state)
  end
end
