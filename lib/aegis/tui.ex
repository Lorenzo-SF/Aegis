defmodule Aegis.Tui do
  @moduledoc """
  Terminal User Interface para Aegis usando OTP 28 raw terminal mode.

  Coordina módulos especializados:
  - Terminal: Manejo del terminal raw mode
  - Renderer`: Renderizado usando Aegis.Printer.message
  - InputHandler: Manejo de entrada de teclado
  - MenuBuilder: Construcción y preparación de menús
  - Core: Bucle principal del TUI
  """

  require Logger

  alias Aegis.Structs.{MenuInfo, MenuState}
  alias Aegis.Tui.{Terminal, MenuBuilder, Core, LogoCache}
  alias Aegis.Printer
  alias Argos.Command

  @doc """
  Punto de entrada principal del TUI.
  Acepta un `%MenuInfo{}` o un `atom` con clave de menú.
  """
  def run(menu) do
    menu
    |> case do
      %MenuInfo{} = m -> m
      key when is_atom(key) -> MenuBuilder.convert_menu_config(key)
    end
    |> show_menu()
  end

  defp show_menu(%{} = menu) do
    ensure_logo_cache_started()
    Terminal.init_raw_terminal()

    try do
      prepared_options = MenuBuilder.prepare_menu_options(menu)
      updated_menu = %{menu | options: prepared_options}

      initial_state = %MenuState{
        pid: :raw_terminal_main,
        menu_info: updated_menu,
        filtered_options: prepared_options,
        terminal_size: Terminal.get_terminal_size(),
        cursor_index: 0,
        search_term: "",
        selected_indices: MapSet.new(),
        ascii_art: updated_menu.ascii_art
      }

      Core.run_tui_loop(initial_state)
    rescue
      error ->
        handle_menu_error(error, __STACKTRACE__)
    after
      Terminal.cleanup_raw_terminal()
      LogoCache.clear_logo()
    end
  end

  @doc """
  Crea un MenuInfo dinámico para uso con raw terminal mode.
  Delega a MenuBuilder.
  """
  def create_dynamic_menu(options, breadcrumbs, opts \\ []),
    do: MenuBuilder.create_dynamic_menu(options, breadcrumbs, opts)

  @doc """
  Genera el logo del menú.
  Delega a MenuBuilder.
  """
  def generate_menu_logo, do: MenuBuilder.generate_menu_logo()

  @doc """
  Obtiene las entradas de menú desde configuración.
  """
  def get_menu_entries, do: Application.get_env(:aegis, :menu)

  # Privadas

  defp ensure_logo_cache_started do
    unless LogoCache.has_logo?() do
      case LogoCache.start_link() do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
      end

      LogoCache.set_logo(MenuBuilder.generate_menu_logo())
    end
  end

  defp handle_menu_error(error, stacktrace) do
    # Log detallado
    Logger.error("Error en TUI:")
    Logger.error(Exception.format(:error, error, stacktrace))

    # Mostrar error al usuario
    Printer.separator(color: :error, align: :left, size: :quarter)
    Printer.question("\nError en el menú. Presiona Enter para salir...")

    # Terminar la ejecución
    Command.halt(1)
  end
end
