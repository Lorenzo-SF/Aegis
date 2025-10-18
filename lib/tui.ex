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
  alias Aegis.Terminal
  alias Aegis.Tui.{MenuBuilder, Core, LogoCache}
  alias Aegis.Printer
  alias Argos.Command

  @clear_screen "\e[2J\e[H"
  @hide_cursor "\e[?25l"
  @show_cursor "\e[?25h"

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
    init_raw_terminal()

    try do
      prepared_options = MenuBuilder.prepare_menu_options(menu)
      updated_menu = %{menu | options: prepared_options}

      initial_state = %MenuState{
        pid: :raw_terminal_main,
        menu_info: updated_menu,
        filtered_options: prepared_options,
        terminal_size: Terminal.size(),
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
      cleanup_raw_terminal()
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

  @doc """
  Verifica si el sistema soporta modo raw.
  """
  def check_raw_mode_support do
    try do
      case System.otp_release() do
        release when release >= "28" ->
          case Code.ensure_loaded(:shell) do
            {:module, :shell} -> :ok
            {:error, reason} -> {:error, "Shell module not available: #{reason}"}
          end

        release ->
          {:error, "OTP #{release} no soporta raw mode. Se requiere OTP 28+"}
      end
    rescue
      _ -> {:error, "Error verificando soporte raw mode"}
    end
  end

  @doc """
  Inicializa el terminal en modo raw.
  """
  def init_raw_terminal do
    IO.write(@hide_cursor <> @clear_screen)

    # Intentar configurar :shell
    try do
      case :shell.start_interactive({:noshell, :raw}) do
        :ok -> :ok
        _ -> :ok
      end
    rescue
      _ -> :ok
    end

    # Configuración de stdio para modo raw más seguro
    try do
      :io.setopts(:stdio, [{:binary, false}, {:echo, false}, {:expand_fun, fn _ -> [] end}])
    rescue
      _ ->
        :io.setopts(:stdio, [{:echo, false}])
    end
  end

  @doc """
  Limpia y restaura el terminal al modo normal.
  """
  def cleanup_raw_terminal do
    IO.write(@show_cursor <> @clear_screen)

    try do
      :io.setopts(:stdio, [{:echo, true}])
    rescue
      _ -> :ok
    end
  end


  @doc """
  Mueve el cursor al inicio y limpia desde cursor hasta el final.
  """
  def clear_from_cursor do
    IO.write("\e[H\e[0J")
  end

  @doc """
  Helper para ejecutar un bloque de código en modo raw, asegurando
  que se restaure el terminal al finalizar.
  """
  def with_terminal(fun) when is_function(fun, 0) do
    init_raw_terminal()

    try do
      fun.()
    after
      cleanup_raw_terminal()
    end
  end
end
