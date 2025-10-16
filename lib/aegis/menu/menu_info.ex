defmodule Aegis.Structs.MenuInfo do
  @moduledoc "Menu information structure for CLI menus."
  alias Aegis.Structs.MenuOption

  @enforce_keys [:options, :breadcrumbs]
  defstruct title: "",
            ascii_art: [""],
            ascii_art_position: :left,
            action_type: nil,
            options: [],
            breadcrumbs: [],
            parent: nil,
            multiselect: false,
            multiselect_next_action: nil

  @type t :: %__MODULE__{
          title: String.t(),
          ascii_art: [String.t()],
          ascii_art_position: :top | :left,
          action_type: :navigation | :execution | :halt | nil,
          options: [MenuOption.t()],
          breadcrumbs: [String.t()],
          parent: atom() | nil,
          multiselect: boolean(),
          multiselect_next_action: (list(MenuOption.t()) -> any()) | nil
        }
end
