defmodule Aegis.Terminal.ModuleRepoInfo do
  @moduledoc """
  Estructura que representa la información del repositorio de un módulo.
  """
  defstruct [
    :url,
    :branch,
    :commit
  ]

  @type t :: %__MODULE__{
    url: String.t(),
    branch: String.t(),
    commit: String.t()
  }

  def from_map(map) when is_map(map) do
    %__MODULE__{
      url: Map.get(map, :url) || Map.get(map, "url"),
      branch: Map.get(map, :branch) || Map.get(map, "branch"),
      commit: Map.get(map, :commit) || Map.get(map, "commit")
    }
  end
end
