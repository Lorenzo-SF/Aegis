defmodule Aegis.Structs.MenuState do
  @moduledoc "Menu option structure for CLI menu items."
  alias Aegis.Structs.MenuInfo

  defstruct pid: nil,
            menu_info: nil,
            filtered_options: [],
            cursor_index: 0,
            search_term: "",
            selected_indices: MapSet.new(),
            terminal_size: {80, 24},
            last_rendered_lines: [],
            search_history: [],
            search_history_index: -1,
            ascii_art: []

  @type t :: %__MODULE__{
          pid: pid() | nil,
          menu_info: MenuInfo.t() | nil,
          filtered_options: [MenuOption.t()],
          cursor_index: non_neg_integer(),
          search_term: String.t(),
          selected_indices: MapSet.t(any()),
          terminal_size: {non_neg_integer(), non_neg_integer()},
          last_rendered_lines: [String.t()],
          search_history: [String.t()],
          search_history_index: integer(),
          ascii_art: [String.t()]
        }
end
