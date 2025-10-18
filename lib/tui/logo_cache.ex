defmodule Aegis.Tui.LogoCache do
  @moduledoc """
  GenServer para cachear el logo generado con gradientes.
  Evita regenerar el logo en cada renderizado, manteniéndolo durante toda la sesión TUI.
  """
  use GenServer

  @name __MODULE__

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, @name))
  end

  def get_logo, do: call_if_started(:get_logo)
  def set_logo(logo_lines) when is_list(logo_lines), do: call_if_started({:set_logo, logo_lines})
  def clear_logo, do: call_if_started(:clear_logo)

  def has_logo?, do: !!get_logo()

  # --- helpers internos ---
  defp call_if_started(msg) do
    case GenServer.whereis(@name) do
      nil -> {:error, :cache_not_started}
      _pid -> GenServer.call(@name, msg)
    end
  end

  ## Server Callbacks

  @impl true
  def init(:ok), do: {:ok, %{logo: nil}}

  @impl true
  def handle_call(:get_logo, _from, %{logo: logo} = state), do: {:reply, logo, state}

  @impl true
  def handle_call({:set_logo, logo_lines}, _from, state),
    do: {:reply, :ok, %{state | logo: logo_lines}}

  @impl true
  def handle_call(:clear_logo, _from, state), do: {:reply, :ok, %{state | logo: nil}}
end
