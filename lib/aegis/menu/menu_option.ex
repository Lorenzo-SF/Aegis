defmodule Aegis.Structs.MenuOption do
  @moduledoc """
  Menu option structure for CLI menu items.

  ## Execution Return Values

  For `:execution` action_type, functions can return special values to control menu behavior:
  - `{:exit_menu, value}` - Exit the menu and return the value
  - `{:continue_menu, value}` - Continue showing the menu after action completes
  - Any other value - Continue showing the menu (default behavior)

  ## Examples

      # Action that exits the menu
      %MenuOption{
        action_type: :execution,
        action: fn -> {:exit_menu, "Done!"} end
      }

      # Action that continues showing menu
      %MenuOption{
        action_type: :execution,
        action: fn -> IO.puts("Task completed!"); {:continue_menu, :ok} end
      }
  """

  @enforce_keys [:id, :name, :action_type, :action]
  defstruct id: 0,
            name: "",
            action_type: :navigation,
            action: nil,
            description: "",
            description_location: :right,
            args: []

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          action_type: :navigation | :execution,
          action: any(),
          description: String.t(),
          description_location: :right | :down,
          args: [String.t()]
        }
end
