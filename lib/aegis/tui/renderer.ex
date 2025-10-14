defmodule Aegis.Tui.Renderer do
  @moduledoc """
  Renderizado de elementos TUI usando Pandr.Printer raw mode.

  Todos los elementos visuales se renderizan usando Pandr.Printer en modo raw
  para mantener consistencia en colores y posicionamiento.
  """

  alias Aurora.{Structs.ChunkText, Color}
  alias Aegis.Printer
  alias Aegis.Tui.LogoCache

  @logo_max_width 40
  @menu_width 20

  @enhanced_cursor "▶ "
  @checkbox_selected "☑ "
  @checkbox_unselected "☐ "

  # --- Render principal ---

  @doc """
  Renderiza el menú completo.
  """
  def render_menu(%{menu_info: %{breadcrumbs: breadcrumbs}} = state) do
    cached_logo = LogoCache.get_logo() || []

    render_logo(cached_logo, logo_start_y(), logo_start_x())
    render_breadcrumbs(breadcrumbs, menu_y(), logo_end_x())

    search_y = menu_y() + 2
    render_search(state, search_y, logo_end_x())

    options_y = search_y + 2
    render_options(state, options_y, logo_end_x())
  end

  # --- Logo ---

  @doc """
  Renderiza el logo ASCII en la posición indicada.
  """
  def render_logo(lines, start_y, start_x) when is_list(lines) do
    Enum.with_index(lines, 1)
    |> Enum.each(fn {line, idx} ->
      y_pos = start_y + idx - 1
      IO.inspect(line, label: "line =>", limit: :infinity, printable_limit: :infinity, charlist: :as_lists)
      IO.write("\e[#{y_pos};#{start_x}H#{line}")
    end)
  end

  def render_logo({:error, :cache_not_started}, _start_y, _start_x) do
    # no hacemos nada, opcional: log de debug
    IO.warn("Logo cache no inicializado, se omite renderizado")
    ""
  end
  defp logo_width(), do: calculate_logo_width(LogoCache.get_logo() || [])
  defp logo_start_x(), do: 2
  defp logo_start_y(), do: 2
  defp logo_end_x(), do: logo_start_x() + min(@logo_max_width, logo_width())
  defp menu_y(), do: logo_start_y() + 3

  # --- Breadcrumbs ---

  @doc """
  Renderiza breadcrumbs si existen.
  """
  def render_breadcrumbs(breadcrumbs, pos_y, pos_x) when length(breadcrumbs) > 0 do
    Printer.breadcrumbs_raw(breadcrumbs, mode: :raw, pos_x: pos_x, pos_y: pos_y)
  end

  def render_breadcrumbs(_, _, _), do: :ok

  # --- Campo de búsqueda ---

  @doc """
  Renderiza el campo de búsqueda.
  """
  def render_search(state, y_pos, x_offset) do
    search_display =
      if String.trim(state.search_term) == "", do: "[escribe para filtrar]", else: "#{state.search_term}_"

    chunks = [
      %ChunkText{text: "Buscar: ", pos_x: x_offset, pos_y: y_pos, color: Color.get_color_info(:info)},
      %ChunkText{text: search_display, pos_x: x_offset + 8, pos_y: y_pos, color: Color.get_color_info(:ternary)}
    ]

    Printer.raw_message(messages: chunks)
  end

  # --- Opciones del menú ---

  @doc """
  Renderiza todas las opciones.
  """
  def render_options(state, start_y, start_x) do
    Enum.with_index(state.filtered_options)
    |> Enum.each(fn {option, idx} ->
      render_option(option, idx, start_y + idx, start_x, state)
    end)
  end

  defp render_option(
         %{id: id, name: name},
         index,
         y_pos,
         x_pos,
         %{cursor_index: cursor_index, selected_indices: selected, menu_info: %{multiselect: ms}}
       ) do
    is_selected = index == cursor_index
    is_marked = MapSet.member?(selected, id)
    {prefix, color} = get_option_style(is_selected, is_marked, ms)
    Printer.raw_message(message: "#{prefix}#{name}", pos_x: x_pos, pos_y: y_pos, color: color)
  end

  defp get_option_style(true, true, true), do: {"#{@enhanced_cursor}#{@checkbox_selected} ", :ternary}
  defp get_option_style(true, false, true), do: {"#{@enhanced_cursor}#{@checkbox_unselected} ", :ternary}
  defp get_option_style(true, _, _), do: {@enhanced_cursor, :ternary}
  defp get_option_style(false, true, true), do: {"  #{@checkbox_selected} ", :ternary}
  defp get_option_style(false, false, true), do: {"  #{@checkbox_unselected} ", :ternary}
  defp get_option_style(_, _, _), do: {"  ", :secondary}

  # --- Logo width calculado ---

  defp calculate_logo_width(logo_lines) when is_list(logo_lines) and length(logo_lines) > 0 do
    logo_lines
    |> Enum.map(&String.length(String.trim(&1)))
    |> Enum.max()
    |> max(@menu_width)
  end

  defp calculate_logo_width(_), do: @menu_width

  # --- Actualización de cursor (sin redibujar todo) ---

  @doc """
  Redibuja solo la línea anterior y la nueva del cursor.
  """
  def render_cursor_update(old_state, new_state) do
    if old_state.cursor_index != new_state.cursor_index do
      options_y = menu_y() + 4
      start_x = logo_end_x()

      # Limpiar y redibujar la línea anterior sin cursor
      old_option = Enum.at(new_state.filtered_options, old_state.cursor_index)
      if old_option do
        old_y = options_y + old_state.cursor_index
        clear_line_from(old_y, start_x)
        render_option(old_option, old_state.cursor_index, old_y, start_x, %{new_state | cursor_index: -1})
      end

      # Limpiar y dibujar la nueva línea con cursor
      new_option = Enum.at(new_state.filtered_options, new_state.cursor_index)
      if new_option do
        new_y = options_y + new_state.cursor_index
        clear_line_from(new_y, start_x)
        render_option(new_option, new_state.cursor_index, new_y, start_x, new_state)
      end
    end
  end

  # --- Utilidades ---

  # Limpia desde X hasta el final de la línea
  defp clear_line_from(y_pos, x_pos), do: IO.write("\e[#{y_pos};#{x_pos}H\e[K")
end
