# terminal_behaviour.ex
defmodule Aegis.Terminal.Behaviour do
  @moduledoc """
  Behaviour para la gestión de terminal cross-platform.
  """

  alias Aegis.Terminal.ModuleInfo
  alias Aegis.Terminal.ModuleIndexInfo

  @type module_info :: ModuleInfo.t()
  @type layout_spec :: %{
    required(:rows) => integer(),
    required(:cols) => integer(),
    optional(:big_pane_positions) => list({integer(), integer()}),
    optional(:layout_type) => atom()
  }

  @callback create_tab(opts :: keyword()) :: {:ok, String.t()} | {:error, String.t()}
  @callback create_pane(opts :: keyword()) :: {:ok, String.t()} | {:error, String.t()}
  @callback close_tab(tab_id :: String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback close_pane(pane_id :: String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback navigate_to_tab(tab_id :: String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback navigate_to_pane(pane_id :: String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback send_command(pane_id :: String.t(), command :: String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback execute_command(pane_id :: String.t(), command :: String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback customize_pane(pane_id :: String.t(), colors :: keyword()) :: {:ok, String.t()} | {:error, String.t()}

  @callback create_screen_session(session_name :: String.t(), command :: String.t(), log_file :: String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback close_screen_session(session_name :: String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback send_command_to_screen(session_name :: String.t(), command :: String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback find_screen_session(session_name :: String.t()) :: {:ok, String.t()} | {:error, String.t()}

  @callback apply_layout(layout_spec :: layout_spec()) :: {:ok, String.t()} | {:error, String.t()}
  @callback create_custom_layout(panes_count :: integer(), layout_type :: atom()) :: {:ok, map()} | {:error, String.t()}

  # Funciones específicas para los casos de uso
  @callback start_application(modules :: list(module_info()), pane_modules :: list(atom()), layout :: layout_spec()) :: {:ok, map()} | {:error, String.t()}
  @callback reindex_application(modules_with_indexes :: list({module_info(), ModuleIndexInfo.t()})) :: {:ok, map()} | {:error, String.t()}
  @callback open_pod_terminal(context :: String.t(), pod_name :: String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback kill_application() :: {:ok, map()} | {:error, String.t()}

  # Funciones de utilidad
  @callback terminal_size() :: {integer(), integer()}
  @callback terminal_width(integer() | nil) :: integer()
  @callback clear_screen() :: :ok
  @callback close_element(element_id :: String.t()) :: {:ok, String.t()} | {:error, String.t()}
end
