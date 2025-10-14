defmodule Aegis.Tui.Terminal do
  @moduledoc """
  Manejo del terminal en modo raw para TUI.

  Proporciona inicialización, configuración y limpieza del terminal
  en modo raw de OTP 28+, con helpers para ejecutar bloques seguros.
  """
  require Logger

  @clear_screen "\e[2J\e[H"
  @hide_cursor "\e[?25l"
  @show_cursor "\e[?25h"

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
  Obtiene el tamaño del terminal. Devuelve `{rows, cols}`.
  """
  def get_terminal_size do
    cols =
      case :io.columns() do
        {:ok, c} -> c
        _ -> 80
      end

    rows =
      case :io.rows() do
        {:ok, r} -> r
        _ -> 24
      end

    {rows, cols}
  end

  @doc """
  Limpia la pantalla completamente.
  """
  def clear_screen do
    IO.write(@clear_screen)
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
