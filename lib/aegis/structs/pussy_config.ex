defmodule Aegis.Structs.PussyConfig do
  @moduledoc """
  Estructura de configuración unificada para Aegis.Terminal.

  Esta estructura normaliza todas las operaciones con terminales (Kitty y Tmux),
  proporcionando una interfaz consistente y opciones configurables.
  """
  
  @behaviour Access

  @type orientation :: :horizontal | :vertical
  @type element_type :: :window | :tab | :pane
  @type colors :: %{foreground: String.t(), background: String.t()}

  @type t :: %__MODULE__{
          # Identificadores
          window_id: String.t() | nil,
          tab_id: String.t() | nil,
          pane_id: String.t() | nil,

          # Configuración de comando
          command: String.t() | nil,
          shell: String.t(),

          # Configuración visual
          colors: colors() | nil,

          # Configuración de layout
          orientation: orientation() | nil,

          # Configuración de comportamiento
          fallback_enabled: boolean(),
          create_if_missing: boolean(),
          focus_after_creation: boolean(),

          # Configuración de socket y timeout
          socket_path: String.t(),
          timeout: non_neg_integer(),

          # Configuración adicional
          working_directory: String.t() | nil,
          environment_vars: map() | nil
        }

  defstruct window_id: nil,
            tab_id: nil,
            pane_id: nil,
            command: nil,
            shell: "/bin/zsh",
            colors: nil,
            orientation: nil,
            fallback_enabled: true,
            create_if_missing: true,
            focus_after_creation: true,
            socket_path: "unix:/tmp/kitty",
            timeout: 30_000,
            working_directory: nil,
            environment_vars: nil

  @doc """
  Crea una nueva configuración PussyConfig con valores por defecto.

  ## Opciones

  - `:window_id` - ID de la ventana (string)
  - `:tab_id` - ID del tab (string)
  - `:pane_id` - ID del pane (string)
  - `:command` - Comando a ejecutar (string)
  - `:shell` - Shell a usar (string, default: "/bin/zsh")
  - `:colors` - Colores foreground/background (map)
  - `:orientation` - Orientación para panes (:horizontal | :vertical)
  - `:fallback_enabled` - Habilitar fallback (boolean, default: true)
  - `:create_if_missing` - Crear elemento si no existe (boolean, default: true)
  - `:focus_after_creation` - Dar focus después de crear (boolean, default: true)
  - `:socket_path` - Ruta del socket Kitty (string, default: "unix:/tmp/kitty")
  - `:timeout` - Timeout en ms (integer, default: 30_000)
  - `:working_directory` - Directorio de trabajo (string)
  - `:environment_vars` - Variables de entorno (map)

  ## Ejemplos

      # Configuración básica para crear un tab
      config = PussyConfig.new(
        window_id: "main",
        tab_id: "backend",
        command: "mix run"
      )

      # Configuración con colores personalizados
      config = PussyConfig.new(
        window_id: "dev",
        colors: %{foreground: "#00FF00", background: "#000000"}
      )

      # Configuración para pane horizontal
      config = PussyConfig.new(
        window_id: "main",
        tab_id: "split",
        pane_id: "logs",
        orientation: :horizontal,
        command: "tail -f log/dev.log"
      )
  """
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  @doc """
  Valida que la configuración sea correcta.

  Retorna `{:ok, config}` si es válida, `{:error, reason}` si no.
  """
  def validate(%__MODULE__{} = config) do
    with :ok <- validate_ids(config),
         :ok <- validate_shell(config),
         :ok <- validate_colors(config),
         :ok <- validate_orientation(config),
         :ok <- validate_socket_path(config),
         :ok <- validate_timeout(config) do
      {:ok, config}
    end
  end

  # Validaciones privadas

  defp validate_ids(%__MODULE__{window_id: window_id, tab_id: tab_id, pane_id: pane_id}) do
    cond do
      window_id && not is_binary(window_id) ->
        {:error, "window_id must be a string"}

      tab_id && not is_binary(tab_id) ->
        {:error, "tab_id must be a string"}

      pane_id && not is_binary(pane_id) ->
        {:error, "pane_id must be a string"}

      pane_id && not tab_id ->
        {:error, "pane_id requires tab_id to be set"}

      tab_id && not window_id ->
        {:error, "tab_id requires window_id to be set"}

      true ->
        :ok
    end
  end

  defp validate_shell(%__MODULE__{shell: shell}) when is_binary(shell), do: :ok
  defp validate_shell(_), do: {:error, "shell must be a string"}

  defp validate_colors(%__MODULE__{colors: nil}), do: :ok
  defp validate_colors(%__MODULE__{colors: colors}) when is_map(colors) do
    required_keys = [:foreground, :background]

    case Enum.all?(required_keys, &Map.has_key?(colors, &1)) do
      true -> :ok
      false -> {:error, "colors must have :foreground and :background keys"}
    end
  end
  defp validate_colors(_), do: {:error, "colors must be a map"}

  defp validate_orientation(%__MODULE__{orientation: nil}), do: :ok
  defp validate_orientation(%__MODULE__{orientation: orientation})
    when orientation in [:horizontal, :vertical], do: :ok
  defp validate_orientation(_), do: {:error, "orientation must be :horizontal or :vertical"}

  defp validate_socket_path(%__MODULE__{socket_path: path}) when is_binary(path), do: :ok
  defp validate_socket_path(_), do: {:error, "socket_path must be a string"}

  defp validate_timeout(%__MODULE__{timeout: timeout})
    when is_integer(timeout) and timeout > 0, do: :ok
  defp validate_timeout(_), do: {:error, "timeout must be a positive integer"}

  @doc """
  Convierte la configuración a una keyword list para compatibilidad.
  """
  def to_opts(%__MODULE__{} = config) do
    config
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into([])
  end

  @doc """
  Genera un ID único para elementos si no está especificado.
  """
  def ensure_id(%__MODULE__{} = config, element_type) do
    case element_type do
      :window when is_nil(config.window_id) ->
        %{config | window_id: generate_id("window")}

      :tab when is_nil(config.tab_id) ->
        %{config | tab_id: generate_id("tab")}

      :pane when is_nil(config.pane_id) ->
        %{config | pane_id: generate_id("pane")}

      _ ->
        config
    end
  end

  defp generate_id(prefix) do
    timestamp = :os.system_time(:millisecond)
    random = :rand.uniform(1000)
    "#{prefix}_#{timestamp}_#{random}"
  end

  # Access behaviour implementation
  def fetch(struct, key) do
    Map.fetch(struct, key)
  end

  def get_and_update(struct, key, fun) do
    Map.get_and_update(struct, key, fun)
  end

  def pop(struct, key, default \\ nil) do
    {Map.get(struct, key, default), struct}
  end
end