defmodule Aegis.Tui.MenuBuilder do
  @moduledoc """
  Construcción y preparación de menús para TUI.

  Maneja estructuras MenuInfo, prepara opciones, y navega entre menús.
  """

  import Argos.Command

  alias Aurora.Format
  alias Aegis.Printer
  alias Aegis.Structs.{MenuInfo, MenuOption, MenuState}
  alias Aegis.Tui.LogoCache
  alias Argos.Structs.CommandResult

  @doc """
  Crea un MenuInfo dinámico para uso en raw terminal mode.
  """
  def create_dynamic_menu(options, breadcrumbs, opts \\ []) do
    parent = Keyword.get(opts, :parent, :main_menu_options)
    multiselect = Keyword.get(opts, :multiselect, false)
    multiselect_next_action = Keyword.get(opts, :multiselect_next_action)

    # Solo genera logo si no está cacheado
    ascii_art =
      Keyword.get(opts, :ascii_art) ||
        LogoCache.get_logo() ||
        generate_and_cache_logo()

    %MenuInfo{
      ascii_art: ascii_art,
      ascii_art_position: :left,
      title: "",
      options: options,
      breadcrumbs: breadcrumbs,
      action_type: :navigation,
      parent: parent,
      multiselect: multiselect,
      multiselect_next_action: multiselect_next_action
    }
  end

  @doc """
  Prepara las opciones de un menú añadiendo Back/Next automáticos.
  """
  def prepare_menu_options(%{
        options: options,
        parent: parent,
        multiselect: multiselect,
        multiselect_next_action: next_action
      }) do
    (options || [])
    |> add_back_option(parent)
    |> add_next_option(multiselect, next_action)
  end

  @doc """
  Convierte un menú desde la configuración de Application o devuelve el mismo MenuInfo.
  """
  def convert_menu_config(menu_key) when is_atom(menu_key) do
    menu_entries = Application.get_env(:aegis, :menu, [])
    menu_config = Keyword.get(menu_entries, menu_key, %{})

    options = get_config_value(menu_config, :options, [])
    breadcrumbs = get_config_value(menu_config, :breadcrumbs, [])
    parent = get_config_value(menu_config, :parent, :main_menu_option)
    multiselect = get_config_value(menu_config, :multiselect, false)

    converted_options =
      Enum.map(options, fn opt ->
        %MenuOption{
          id: get_config_value(opt, :id, 0),
          name: get_config_value(opt, :name, "Sin nombre"),
          action_type: get_config_value(opt, :action_type, :navigation),
          action: get_config_value(opt, :action, :main_menu_option),
          description: get_config_value(opt, :description, ""),
          description_location: get_config_value(opt, :description_location, :right),
          args: get_config_value(opt, :args, [])
        }
      end)

    %MenuInfo{
      ascii_art: LogoCache.get_logo() || generate_and_cache_logo(),
      ascii_art_position: :left,
      title: "",
      options: converted_options,
      breadcrumbs: breadcrumbs,
      parent: parent,
      multiselect: multiselect,
      multiselect_next_action: nil
    }
  end

  def convert_menu_config(menu_info) when is_map(menu_info), do: struct(MenuInfo, menu_info)
  def convert_menu_config(_), do: %MenuInfo{options: [], breadcrumbs: []}

  @doc """
  Ejecuta la acción de una opción de menú.
  """
  def execute_option_action(state, %MenuOption{
        action_type: :execution,
        action: action,
        args: args
      })
      when is_function(action) do
    arity = Keyword.fetch!(Function.info(action), :arity)
    execute_action(action, arity, args, state)
  end

  def execute_option_action(state, %MenuOption{action_type: :navigation, action: menu_key}) do
    try do
      new_menu = convert_menu_config(menu_key)
      prepared_options = prepare_menu_options(new_menu)
      updated_menu = %{new_menu | options: prepared_options}

      new_state = %MenuState{
        state
        | menu_info: updated_menu,
          filtered_options: prepared_options,
          cursor_index: 0,
          search_term: "",
          selected_indices: MapSet.new(),
          ascii_art: updated_menu.ascii_art
      }

      {:navigate, new_state}
    rescue
      error -> {:error, "Error navegando a #{menu_key}: #{Exception.message(error)}"}
    end
  end

  @doc """
  Genera y cachea el logo para el menú.
  """
  def generate_and_cache_logo do
    lines = generate_menu_logo()
    LogoCache.set_logo(lines)
    lines
  end

  def generate_menu_logo do
    {lines, gradient_hexes} = Format.format_logo(Printer.get_header_logo())

    gradients = Enum.map_join(gradient_hexes, " ", fn h -> "'#{h}'" end)

    cmd = "echo '#{lines}' | gterm #{gradients}"

    %CommandResult{
      output: output,
      success?: success
    } = exec!(cmd)

    if success, do: String.split(output, "\n"), else: String.split(lines, "\n")
  end

  @doc """
  Devuelve líneas del logo por defecto si no hay ninguno.
  """
  def get_logo_lines do
    Application.get_env(:aegis, :logos, %{})[:long_header] ||
      ["═══ TRUS ═══", "  Sistema CLI  ", "══════════════"]
  end

  # --- Funciones privadas ---

  defp add_back_option(options, nil), do: options

  defp add_back_option(options, parent) do
    if Enum.any?(options, &(&1.id == :back)),
      do: options,
      else: [create_back_option(parent) | options]
  end

  defp add_next_option(options, true, next_action) when not is_nil(next_action),
    do: options ++ [create_next_option(next_action)]

  defp add_next_option(options, _, _), do: options

  defp create_back_option(parent) do
    %MenuOption{
      id: :back,
      name: "Volver",
      action_type: :navigation,
      action: parent,
      description: "Volver al menú anterior",
      args: []
    }
  end

  defp create_next_option(next_action) do
    %MenuOption{
      id: :next,
      name: "Siguiente",
      action_type: :execution,
      action: next_action,
      description: "Continuar con elementos seleccionados",
      args: []
    }
  end

  # Ejecuta acciones con multiselect o no
  defp execute_action(action, _arity, args, %{menu_info: %{multiselect: true}} = state) do
    selected_options = get_selected_options(state)
    apply(action, [selected_options | args])
  end

  defp execute_action(action, arity, args, %{menu_info: %{multiselect: false}})
       when is_function(action) and arity > 0 do
    apply(action, Enum.take(args, arity))
  end

  defp execute_action(action, 0, _args, _state) when is_function(action), do: apply(action, [])

  defp get_selected_options(state) do
    state.filtered_options
    |> Enum.filter(&MapSet.member?(state.selected_indices, &1.id))
    |> Enum.map(& &1.name)
  end

  defp get_config_value(config, key, default) when is_map(config),
    do: Map.get(config, key, default)

  defp get_config_value(config, key, default) when is_list(config),
    do: Keyword.get(config, key, default)

  defp get_config_value(_, _, default), do: default
end
