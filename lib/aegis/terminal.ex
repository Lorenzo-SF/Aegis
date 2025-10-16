# terminal.ex
defmodule Aegis.Terminal do
  @moduledoc """
  Módulo principal para gestión de terminal cross-platform.
  Detecta el sistema operativo y delega en la implementación correspondiente.
  """

  alias Aegis.Terminal.{Bash, PowerShell}
  alias Aegis.Terminal.ModuleInfo

  @spec get_impl() :: module()
  defp get_impl() do
    case :os.type() do
      {:win32, _} -> PowerShell
      _ -> Bash  # Unix-like systems (Linux, macOS)
    end
  end

  # Delegación dinámica de todas las funciones del behaviour
  @behaviour_functions [
    :create_tab, :create_pane, :close_tab, :close_pane, :navigate_to_tab,
    :navigate_to_pane, :send_command, :execute_command, :customize_pane,
    :create_screen_session, :close_screen_session, :send_command_to_screen,
    :find_screen_session, :apply_layout, :create_custom_layout,
    :start_application, :reindex_application, :open_pod_terminal, :kill_application
  ]

  @non_behaviour_functions [:terminal_size]

  for function <- @behaviour_functions do
    args = if function in [:send_command, :execute_command, :customize_pane, :send_command_to_screen] do
      quote do
        [arg1, arg2]
      end
    else
      quote do
        [arg]
      end
    end

    defdelegate unquote(function)(unquote_splicing(args)), to: __MODULE__, as: :"delegate_#{function}"
  end

  # Implementaciones de delegación
  defp delegate_create_tab(opts), do: get_impl().create_tab(opts)
  defp delegate_create_pane(opts), do: get_impl().create_pane(opts)
  defp delegate_close_tab(tab_id), do: get_impl().close_tab(tab_id)
  defp delegate_close_pane(pane_id), do: get_impl().close_pane(pane_id)
  defp delegate_navigate_to_tab(tab_id), do: get_impl().navigate_to_tab(tab_id)
  defp delegate_navigate_to_pane(pane_id), do: get_impl().navigate_to_pane(pane_id)
  defp delegate_send_command(pane_id, command), do: get_impl().send_command(pane_id, command)
  defp delegate_execute_command(pane_id, command), do: get_impl().execute_command(pane_id, command)
  defp delegate_customize_pane(pane_id, colors), do: get_impl().customize_pane(pane_id, colors)
  defp delegate_create_screen_session(session, cmd, log), do: get_impl().create_screen_session(session, cmd, log)
  defp delegate_close_screen_session(session), do: get_impl().close_screen_session(session)
  defp delegate_send_command_to_screen(session, cmd), do: get_impl().send_command_to_screen(session, cmd)
  defp delegate_find_screen_session(session), do: get_impl().find_screen_session(session)
  defp delegate_apply_layout(layout), do: get_impl().apply_layout(layout)
  defp delegate_create_custom_layout(count, type), do: get_impl().create_custom_layout(count, type)
  defp delegate_start_application(modules, pane_modules, layout), do: get_impl().start_application(modules, pane_modules, layout)
  defp delegate_reindex_application(modules_indexes), do: get_impl().reindex_application(modules_indexes)
  defp delegate_open_pod_terminal(context, pod), do: get_impl().open_pod_terminal(context, pod)
  defp delegate_kill_application(), do: get_impl().kill_application()

  # Funciones de alto nivel para los casos de uso específicos
  @doc """
  Inicia la aplicación Truedat con los módulos especificados.

  ## Parámetros
    - modules: Lista de ModuleInfo
    - pane_modules: Lista de aliases de módulos que se mostrarán en panes
    - layout_type: Tipo de layout (:default, :grid_4x4, etc.)
  """
  def start_truedat(modules, pane_modules \\ [], layout_type \\ :default) do
    layout = get_layout_spec(layout_type)
    impl = get_impl()
    impl.start_application(modules, pane_modules, layout)
  end

  @doc """
  Ejecuta el reindexado de la aplicación.

  ## Parámetros
    - modules: Lista de ModuleInfo con índices
  """
  def reindex_truedat(modules) do
    modules_with_indexes = extract_modules_with_indexes(modules)
    impl = get_impl()
    impl.reindex_application(modules_with_indexes)
  end

  @doc """
  Abre una terminal en un pod de Kubernetes.
  """
  def open_kubectl_pod(context, pod_name) do
    impl = get_impl()
    impl.open_pod_terminal(context, pod_name)
  end

  @doc """
  Mata todos los procesos relacionados con Truedat.
  """
  def kill_truedat() do
    impl = get_impl()
    impl.kill_application()
  end

  @doc """
  Verifica si el terminal está disponible.
  """
  def available? do
    impl = get_impl()
    # Verificación básica - podríamos verificar comandos específicos
    case impl.create_tab(name: "test", command: "echo test") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Obtiene el tipo de terminal detectado.
  """
  def terminal_type do
    case get_impl() do
      Bash -> :bash
      PowerShell -> :powershell
    end
  end

  # Helpers privados
  defp get_layout_spec(:default) do
    %{
      rows: 4,
      cols: 4,
      big_pane_positions: [{1, 3}, {1, 4}, {2, 3}, {2, 4}],
      layout_type: :grid_4x4
    }
  end

  defp get_layout_spec(:grid_4x4) do
    %{
      rows: 4,
      cols: 4,
      layout_type: :grid_4x4
    }
  end

  defp get_layout_spec(:vertical_stack) do
    %{
      rows: 1,
      cols: 1,
      layout_type: :vertical_stack
    }
  end

  defp get_layout_spec(:horizontal_split) do
    %{
      rows: 1,
      cols: 1,
      layout_type: :horizontal_split
    }
  end

  defp get_layout_spec(layout_type) do
    %{layout_type: layout_type}
  end

  defp extract_modules_with_indexes(modules) do
    modules
    |> Enum.flat_map(fn module ->
      Enum.map(module.indexes, fn index ->
        {module, index}
      end)
    end)
  end

  @doc """
  Gets the current terminal size as {width, height}.
  """
  def terminal_size do
    get_impl().terminal_size()
  end

  @doc """
  Gets the current terminal width.
  """
  def terminal_width(size \\ nil) do
    case size do
      nil ->
        {width, _height} = terminal_size()
        width
      _ ->
        size
    end
  end

  @doc """
  Clears the terminal screen.
  """
  def clear_screen do
    get_impl().clear_screen()
  end
end
