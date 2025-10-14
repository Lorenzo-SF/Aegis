defmodule Aegis.Terminal do
  @moduledoc """
  Gestión de terminal cross-platform para Aegis.
  """

  alias Aegis.Terminal.{Iterm2, Kitty, Tmux}
  alias Aegis.Structs.PussyConfig

  # -------------------- Delegation Helper --------------------
  defp delegate_terminal(func, config_or_opts, fallback \\ fn -> {:ok, "Terminal no soportado"} end) do
    terminal = detected_terminal()

    target =
      case terminal do
        :kitty -> Kitty
        :tmux -> Tmux
        :iterm2 -> Iterm2
        _ -> nil
      end

    cond do
      target -> apply(target, func, [PussyConfig.to_opts(config_or_opts)])
      true -> fallback.()
    end
  end

  # -------------------- Terminal detection --------------------
  defp detected_terminal do
    case Process.get(:detected_terminal) do
      nil ->
        term =
          cond do
            System.get_env("TMUX") -> :tmux
            System.get_env("KITTY_WINDOW_ID") -> :kitty
            iterm2?() -> :iterm2
            true -> :unknown
          end

        Process.put(:detected_terminal, term)
        term

      cached -> cached
    end
  end

  defp iterm2? do
    case System.cmd("osascript", ["-e", "tell application \"System Events\" to name of first process whose frontmost is true"], stderr_to_stdout: true) do
      {app_name, 0} -> String.contains?(String.downcase(String.trim(app_name)), "iterm")
      _ -> false
    end
  end

  # -------------------- Tabs / Windows / Panes --------------------
  def create_tab(config_or_opts) do
    config = normalize_config(config_or_opts)
    delegate_terminal(:create_tab, config, fn -> fallback_create_tab(config) end)
  end

  def create_window(config_or_opts) do
    config = normalize_config(config_or_opts)
    delegate_terminal(:create_window, config)
  end

  def create_pane(config_or_opts) do
    config = normalize_config(config_or_opts)
    delegate_terminal(:create_pane, config, fn -> {:ok, "Fallback: Pane no soportado"} end)
  end

  # -------------------- Commands --------------------
  def send_command(config_or_opts) do
    config = normalize_config(config_or_opts)
    delegate_terminal(:send_command, config, fn -> fallback_run_command(config.command) end)
  end

  def run_command(config_or_opts) do
    config = normalize_config(config_or_opts)
    delegate_terminal(:send_command, config, fn -> fallback_run_command(config.command) end)
  end

  defp fallback_run_command(command) do
    case Argos.exec_command(command) do
      {:ok, output} -> {:ok, output}
      error -> error
    end
  end

  # -------------------- Layouts / Styles --------------------
  def apply_layout(config_or_opts) do
    config = normalize_config(config_or_opts)
    delegate_terminal(:apply_layout, config)
  end

  def apply_styles(config_or_opts) do
    config = normalize_config(config_or_opts)
    delegate_terminal(:apply_styles, config)
  end

  def create_trus_layout(tab_name, services) do
    config = %PussyConfig{tab_id: tab_name}
    delegate_terminal(:create_trus_layout, config, fn -> {:ok, %{layout: "trus_4x4", panes_created: length(services), terminal: detected_terminal()}} end)
  end

  def create_trus_services_layout(tab_name, services) do
    config = %PussyConfig{tab_id: tab_name}
    delegate_terminal(:create_trus_services_layout, config, fn -> {:ok, %{layout: "trus_services", panes_created: length(services), terminal: detected_terminal()}} end)
  end

  # -------------------- Navigation --------------------
  def navigate_to(config_or_opts) do
    config = normalize_config(config_or_opts)
    delegate_terminal(:navigate_to, config)
  end

  # -------------------- Elements --------------------
  def list_elements(type \\ :all), do: delegate_terminal(:list_elements, %{type: type}, fn -> {:ok, []} end)
  def find_element(opts), do: delegate_terminal(:find_element, opts, fn -> {:error, "Elemento no encontrado"} end)

  # -------------------- Element Management --------------------
  def close_element(config_or_opts) do
    config = normalize_config(config_or_opts)
    delegate_terminal(:close_element, config, fn -> {:ok, "Close element not supported"} end)
  end

  # -------------------- Utilities --------------------
  def terminal_size do
    width = case :io.columns() do
      {:ok, w} -> w
      {:error, _} -> 80  # Default width if error
      w when is_integer(w) -> w  # In some versions it returns integer directly
    end

    height = case :io.rows() do
      {:ok, h} -> h
      {:error, _} -> 24  # Default height if error
      h when is_integer(h) -> h  # In some versions it returns integer directly
    end

    {width, height}
  end

  def terminal_width(size \\ :full) do
    {width, _} = terminal_size()
    case size do
      :full -> width
      :half -> div(width, 2)
      :quarter -> div(width, 4)
      _ -> width
    end
  end

  def autoresize(width, height) do
    delegate_terminal(:resize, %{width: width, height: height}, fn -> {:ok, "Auto-resize no soportado"} end)
  end

  def available?, do: detected_terminal() != :unknown

  def clear_screen, do: Argos.exec_command("clear")

  # -------------------- Legacy helper --------------------
  defp normalize_config(%PussyConfig{} = config), do: config
  defp normalize_config(command) when is_binary(command), do: %PussyConfig{command: command}
  defp normalize_config(opts) when is_list(opts), do: %PussyConfig{command: opts[:command]}

  # -------------------- Fallbacks --------------------
  defp fallback_create_tab(%PussyConfig{command: command}) do
    case detected_terminal() do
      :kitty ->
        case System.cmd("kitty", ["@", "launch", "--type=tab", command], stderr_to_stdout: true) do
          {_, 0} -> {:ok, "Tab creada en Kitty"}
          error -> {:error, "No se pudo crear tab en Kitty: #{inspect(error)}"}
        end
      _ -> Argos.exec_command(command)
    end
  end
end
