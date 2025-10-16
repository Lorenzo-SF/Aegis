defmodule Aegis.Terminal.ModuleIndexInfo do
  @moduledoc """
  Estructura que representa la información de índices de un módulo.
  """
  defstruct [
    :name,
    :script
  ]

  @type t :: %__MODULE__{
    name: String.t(),
    script: String.t()
  }

  def from_map(map) when is_map(map) do
    %__MODULE__{
      name: Map.get(map, :name) || Map.get(map, "name"),
      script: Map.get(map, :script) || Map.get(map, "script")
    }
  end
end
