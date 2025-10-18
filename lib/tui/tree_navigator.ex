defmodule Aegis.Tui.TreeNavigator do
  @moduledoc """
  Navegador TUI interactivo para estructuras de árbol de backups.

  Muestra solo carpetas finales (las que contienen fechas de backup)
  y permite navegación usando el menú TUI.
  """

  alias Aegis.Printer
  alias Aegis.Tui

  @doc """
  Navega interactivamente por un árbol de directorios de backups.

  ## Parámetros
  - `paths`: Lista de rutas que representan las carpetas finales navegables
  - `opts`: Opciones de configuración (:title, :breadcrumbs)

  ## Retorna
  - `{:ok, selected_path}`: Ruta seleccionada por el usuario
  - `:cancelled`: Usuario canceló (ESC)
  """
  @spec navigate([String.t()], keyword()) :: {:ok, String.t()} | :cancelled
  def navigate(paths, opts \\ []) do
    if Enum.empty?(paths) do
      Printer.error("No hay rutas para navegar")
      :cancelled
    else
      Printer.info("📂 Selecciona el backup a aplicar:")

      backup_options = create_backup_menu_options(paths)
      title = Keyword.get(opts, :title, "Selección de backup")
      breadcrumbs = Keyword.get(opts, :breadcrumbs, ["Principal", "Db2", title])

      case Tui.run(%{
             options: backup_options,
             breadcrumbs: breadcrumbs,
             search_enabled: true
           }) do
        {:ok, selected_path} -> {:ok, selected_path}
        :back -> :cancelled
        :exit -> :cancelled
        _ -> :cancelled
      end
    end
  end

  @doc """
  Navega usando un tree pre-generado (compatibilidad Gearbox.Pathy).
  """
  @spec navigate_with_tree([String.t()], String.t(), keyword()) :: {:ok, String.t()} | :cancelled
  def navigate_with_tree(paths, _tree_text, opts), do: navigate(paths, opts)

  # ============================================================================
  # Auxiliares
  # ============================================================================
  defp create_backup_menu_options(paths) do
    paths
    |> Enum.filter(&backup_folder?/1)
    |> Enum.map(fn path ->
      display_name = format_backup_display_name(path)

      %{
        key: String.to_atom("backup_#{:erlang.phash2(path)}"),
        display: display_name,
        action: fn -> {:ok, path} end,
        searchable_text: "#{display_name} #{path}"
      }
    end)
    |> add_back_option()
  end

  defp backup_folder?(path) do
    basename = Path.basename(path)
    String.match?(basename, ~r/^\d{4}-\d{2}-\d{2}/)
  end

  defp format_backup_display_name(path) do
    parts = String.split(path, "/")

    case Enum.reverse(parts) do
      [date_folder, context | _] -> "#{context} / #{date_folder}"
      [date_folder] -> date_folder
      _ -> Path.basename(path)
    end
  end

  defp add_back_option(options) do
    back_option = %{
      key: :back,
      display: "🔙 Volver",
      action: fn -> :back end,
      searchable_text: "volver back"
    }

    options ++ [back_option]
  end
end
