defmodule Aegis.Tui.InputHandler do
  @moduledoc """
  Manejo de entrada de teclado para TUI.

  Se encarga de leer caracteres del teclado en modo raw y
  convertirlos a eventos de menú.
  """

  @key_escape 27
  @key_ctrl_c 3
  @key_enter 10
  @key_carriage_return 13
  @key_backspace [127, 8]

  @doc """
  Lee un carácter del teclado en modo raw.
  """
  def read_raw_char do
    case IO.getn("", 1) do
      <<char::integer>> when char == @key_escape -> read_escape_sequence()
      <<char::integer>> -> {:ok, char}
      :eof -> {:error, :eof}
      error -> {:error, error}
    end
  end

  @doc """
  Maneja una tecla presionada y devuelve la acción correspondiente.
  """
  def handle_key(_state, key) when key in [@key_escape, @key_ctrl_c], do: {:exit, :cancelled}

  def handle_key(state, key) when key in [@key_enter, @key_carriage_return] do
    case selected_option(state) do
      nil -> {:continue, state}
      option -> {:execute, option}
    end
  end

  def handle_key(state, :up_arrow), do: move_cursor(state, -1)
  def handle_key(state, :down_arrow), do: move_cursor(state, 1)

  def handle_key(state, :right_arrow) do
    if state.menu_info.multiselect, do: toggle_selection(state, true), else: {:continue, state}
  end

  def handle_key(state, :left_arrow) do
    if state.menu_info.multiselect, do: toggle_selection(state, false), else: {:continue, state}
  end

  def handle_key(state, char) when char in @key_backspace do
    if state.search_term != "" do
      update_search(state, String.slice(state.search_term, 0..-2//1))
    else
      {:continue, state}
    end
  end

  def handle_key(state, char) when is_integer(char) and char in 32..126 do
    update_search(state, state.search_term <> <<char>>)
  end

  def handle_key(state, _), do: {:continue, state}

  # --- privadas ---

  defp read_escape_sequence do
    case IO.getn("", 1) do
      "[" ->
        case IO.getn("", 1) do
          "A" ->
            {:ok, :up_arrow}

          "B" ->
            {:ok, :down_arrow}

          "C" ->
            {:ok, :right_arrow}

          "D" ->
            {:ok, :left_arrow}

          _ ->
            {:ok, @key_escape}
        end

      _ ->
        {:ok, @key_escape}
    end
  end

  defp selected_option(state), do: Enum.at(state.filtered_options, state.cursor_index)

  defp move_cursor(state, delta) do
    max_index = max(length(state.filtered_options) - 1, 0)
    new_index = min(max(state.cursor_index + delta, 0), max_index)
    {:continue, %{state | cursor_index: new_index}}
  end

  defp toggle_selection(state, select) do
    case selected_option(state) do
      nil ->
        {:continue, state}

      option ->
        updated =
          if select,
            do: MapSet.put(state.selected_indices, option.id),
            else: MapSet.delete(state.selected_indices, option.id)

        {:continue, %{state | selected_indices: updated}}
    end
  end

  defp update_search(state, search_term) do
    filtered_options =
      if String.trim(search_term) == "" do
        state.menu_info.options
      else
        search = String.downcase(search_term)

        Enum.filter(state.menu_info.options, fn option ->
          String.contains?(String.downcase(option.name), search) or
            String.contains?(String.downcase(option.description || ""), search)
        end)
      end

    new_cursor =
      if filtered_options != [],
        do: min(state.cursor_index, length(filtered_options) - 1),
        else: 0

    {:update_search,
     %{
       state
       | search_term: search_term,
         filtered_options: filtered_options,
         cursor_index: new_cursor
     }}
  end
end
