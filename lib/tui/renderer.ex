defmodule Aegis.Tui.Renderer do
  @moduledoc """
  Renderizado de elementos TUI usando Pandr.Printer raw mode.

  Todos los elementos visuales se renderizan usando Pandr.Printer en modo raw
  para mantener consistencia en colores y posicionamiento.
  """

  alias Aurora.{Structs.ChunkText, Color, Ensure}
  alias Aegis.{Printer, Terminal}
  alias Aegis.Tui.LogoCache

  @logo_max_width 40

  @enhanced_cursor "▶ "
  @checkbox_selected "☑ "
  @checkbox_unselected "☐ "
  @margen 2
  @borde %{
    tl: "╭",
    tr: "╮",
    br: "╯",
    bl: "╰",
    hor: "─",
    ver: "│",
    cross: "┼",
    top_cross: "┬",
    bottom_cross: "┴",
    right_cross: "┤",
    left_cross: "├"
  }
  # --- Render principal ---

  @doc """
  Renderiza el menú completo.
  """
  def render_menu(%{
          filtered_options: filtered_options,
          search_term: search_term,
          menu_info: %{
            breadcrumbs: breadcrumbs,
            options: options
          }} = state) do
    cached_logo = LogoCache.get_logo() || []

    frames_height = calculate_menu_height(options)
    frames_width = calculate_menu_width(breadcrumbs, options, search_term)

    render_menu_frame(frames_height,frames_width ,2,3)
    render_logo(cached_logo, logo_start_y(), logo_start_x())
    render_breadcrumbs(breadcrumbs, menu_y(), logo_end_x())
    search_y = menu_y() + 2
    render_search(search_term, search_y, logo_end_x())

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
      Printer.write_at(line, start_x, y_pos)
    end)
  end

  def render_logo({:error, :cache_not_started}, _start_y, _start_x) do
    # no hacemos nada, opcional: log de debug
    IO.warn("Logo cache no inicializado, se omite renderizado")
    ""
  end

  defp logo_width() do
    Printer.get_header_logo()
          |> Enum.map(&String.length/1)
          |> Enum.max()
          |> Kernel.||(0)
  end

  defp logo_start_x(), do: 2
  defp logo_start_y(), do: 2
  defp logo_end_x(), do: logo_start_x() + min(@logo_max_width, logo_width()) + @margen + @margen
  defp menu_y(), do: logo_start_y() + 2 + @margen

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
  def render_search(search_term, y_pos, x_offset) do
    search_display =
      search_term
      |> String.trim()
      |> show_search_term()

    chunks = [
      %ChunkText{
        text: search_label(),
        pos_x: x_offset,
        pos_y: y_pos,
        color: Color.get_color_info(:info)
      },
      %ChunkText{
        text: search_display,
        pos_x: x_offset + 8,
        pos_y: y_pos,
        color: Color.get_color_info(:ternary)
      }
    ]

    Printer.raw_message(messages: chunks)
  end

  defp search_label(), do: "Buscar: "
  defp show_search_term(""), do: "[escribe para filtrar]"
  defp show_search_term(search_term), do: "#{search_term}_"

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

    # Escribir espacios para limpiar completamente desde x_pos hasta el final de la línea
    # Esto evita problemas con secuencias ANSI y residuos
    # get_terminal_size() retorna {rows, cols} = {height, width}

    # Ahora escribir el contenido real
    Printer.raw_message(message: "#{prefix}#{name}", pos_x: x_pos, pos_y: y_pos, color: color)
  end

  defp get_option_style(true, true, true),
    do: {"#{@enhanced_cursor}#{@checkbox_selected} ", :ternary}

  defp get_option_style(true, false, true),
    do: {"#{@enhanced_cursor}#{@checkbox_unselected} ", :ternary}

  defp get_option_style(true, _, _), do: {@enhanced_cursor, :ternary}
  defp get_option_style(false, true, true), do: {"  #{@checkbox_selected} ", :ternary}
  defp get_option_style(false, false, true), do: {"  #{@checkbox_unselected} ", :ternary}
  defp get_option_style(_, _, _), do: {"  ", :secondary}


  # --- Actualización de cursor (sin redibujar todo) ---

  @doc """
  Redibuja solo la línea anterior y la nueva del cursor.
  """
  def render_cursor_update(old_state, new_state) do
    if old_state.cursor_index != new_state.cursor_index do
      options_y = menu_y()  + @margen + @margen
      start_x = logo_end_x()

      # Redibujar la línea anterior sin cursor
      old_option = Enum.at(new_state.filtered_options, old_state.cursor_index)

      if old_option do
        old_y = options_y + old_state.cursor_index

        render_option(old_option, old_state.cursor_index, old_y, start_x, %{
          new_state
          | cursor_index: -1
        })
      end

      # Dibujar la nueva línea con cursor
      new_option = Enum.at(new_state.filtered_options, new_state.cursor_index)

      if new_option do
        new_y = options_y + new_state.cursor_index
        render_option(new_option, new_state.cursor_index, new_y, start_x, new_state)
      end
    end
  end

  # --- Utilidades ---
  defp calculate_menu_height(options) do
      logo_height = length(Printer.get_header_logo())
      menu_height = length(options) + 9
      frame_height = max(logo_height, menu_height)
      [max(logo_height + @margen, menu_height + @margen)]
  end

  defp calculate_menu_width(breadcrumbs, options, search_term) do
    col1_width =
      Printer.get_header_logo()
      |> Enum.map(&String.length/1)
      |> Enum.max()
      |> Kernel.||(0)  # <- Valor por defecto si es nil

    breadcrumbs_width = String.length(Enum.join(breadcrumbs, " > "))

    search_width =
      search_term
      |> String.trim()
      |> show_search_term()
      |> Ensure.list()
      |> Enum.concat([search_label()])
      |> Enum.join()
      |> String.length()

    options_width =
      options
      |> Enum.map(&Map.get(&1, :name))
      |> Enum.map(&String.length/1)
      |> Enum.max(fn -> 0 end)

    col2_width = Enum.max([breadcrumbs_width + @margen, search_width + @margen, options_width + @margen])

    # Devolver números
    [col1_width + @margen, col2_width + @margen]
  end

  defp scan_offsets(sizes, start) do
    Enum.reduce(sizes, [start], fn size, acc ->
      current_size =
        cond do
          is_integer(size) -> size
          is_binary(size) -> String.length(size)
          true -> 0
        end
      [hd(acc) + current_size | acc]
    end)
    |> Enum.reverse()
  end


 def render_menu_frame(rows, cols, pos_x \\ 1, pos_y \\ 1) do
    IO.write("\e[2J") # limpiar pantalla

    # Normalizar a listas
    rows = if is_list(rows), do: rows, else: [rows]
    cols = if is_list(cols), do: cols, else: [cols]

    # Calcular posiciones absolutas (bordes)
    row_offsets = scan_offsets(rows, pos_y)
    col_offsets = scan_offsets(cols, pos_x)

    total_rows = length(rows)
    total_cols = length(cols)


    # Dibujar cruces y esquinas
    for r_idx <- 0..total_rows do
      y = Enum.at(row_offsets, r_idx)

      for c_idx <- 0..total_cols do
        x = Enum.at(col_offsets, c_idx)

        char =
          cond do
            r_idx == 0 and c_idx == 0 -> @borde.tl
            r_idx == 0 and c_idx == total_cols -> @borde.tr
            r_idx == total_rows and c_idx == 0 -> @borde.bl
            r_idx == total_rows and c_idx == total_cols -> @borde.br
            r_idx == 0 -> @borde.top_cross
            r_idx == total_rows -> @borde.bottom_cross
            c_idx == 0 -> @borde.left_cross
            c_idx == total_cols -> @borde.right_cross
            true -> @borde.cross
          end

        print_frame(y, x, char)
      end
    end

    # Líneas horizontales
    for r_idx <- 0..total_rows do
      y = Enum.at(row_offsets, r_idx)
      for c_idx <- 0..(total_cols - 1) do
        start_x = Enum.at(col_offsets, c_idx) + 1
        end_x = Enum.at(col_offsets, c_idx + 1) - 1
        if start_x <= end_x do
          for x <- start_x..end_x, do: print_frame(y, x, @borde.hor)
        end
      end
    end

    # Líneas verticales
    for c_idx <- 0..total_cols do
      x = Enum.at(col_offsets, c_idx)
      for r_idx <- 0..(total_rows - 1) do
        start_y = Enum.at(row_offsets, r_idx) + 1
        end_y = Enum.at(row_offsets, r_idx + 1) - 1
        if start_y <= end_y do
          for y <- start_y..end_y, do: print_frame(y, x, @borde.ver)
        end
      end
    end

    IO.write("")
    :ok
  end

  defp print_frame(y, x, text) do
    Printer.raw_message(
      messages: [
        %ChunkText{
          text: text,
          pos_x: x,
          pos_y: y,
          color: Color.get_color_info(:ternary)
        }
      ]
    )
  end
end
