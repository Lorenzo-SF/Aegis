defmodule Aegis.Terminal.ModuleInfo do
  @moduledoc """
  Estructura que representa la información completa de un módulo.
  """
  defstruct [
    :alias,
    :name,
    :path,
    :script,
    :type,
    indexes: [],
    repo: nil
  ]

  @type t :: %__MODULE__{
    alias: atom(),
    name: String.t(),
    path: String.t(),
    script: String.t(),
    type: atom(),
    indexes: list(Aegis.Terminal.ModuleIndexInfo.t()),
    repo: Aegis.Terminal.ModuleRepoInfo.t() | nil
  }

  def from_map(map) when is_map(map) do
    %__MODULE__{
      alias: Map.get(map, :alias) || Map.get(map, "alias"),
      name: Map.get(map, :name) || Map.get(map, "name"),
      path: Map.get(map, :path) || Map.get(map, "path"),
      script: Map.get(map, :script) || Map.get(map, "script"),
      type: Map.get(map, :type) || Map.get(map, "type"),
      indexes: (Map.get(map, :indexes) || Map.get(map, "indexes", []))
               |> Enum.map(&Aegis.Terminal.ModuleIndexInfo.from_map/1),
      repo: if(Map.get(map, :repo) || Map.get(map, "repo"),
             do: Aegis.Terminal.ModuleRepoInfo.from_map(Map.get(map, :repo) || Map.get(map, "repo")),
             else: nil)
    }
  end
end
