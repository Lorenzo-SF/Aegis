defmodule Aegis do
  @moduledoc """
  CLI/TUI Framework para Elixir - Nivel 2 de Proyecto Ypsilon

  Framework completo para crear interfaces de línea de comandos hermosas e interactivas
  con menús, animaciones, y control avanzado de terminal.

  ## Características

  - 🎨 Sistema de impresión con colores, tablas, y estilos
  - 📋 Menús interactivos con selección múltiple
  - 🌀 Animaciones y spinners
  - 💻 Control de terminal (Kitty, Tmux, iTerm2)
  - 🌐 Integración con Aurora (formatting) y Argos (execution)

  ## Uso Rápido

      # Mensajes con colores
      Aegis.success("Operación completada")
      Aegis.error("Algo salió mal")
      Aegis.warning("Ten cuidado")
      Aegis.info("Procesando...")

      # Tablas y encabezados
      headers = ["Nombre", "Edad"]
      rows = [["Juan", "30"]]
      Aegis.table(headers, rows)

      # Menús interactivos
      Aegis.Tui.run(options)

  ## Arquitectura

  Aegis forma parte de Proyecto Ypsilon:

  ```
                    ┌─────────────────┐
                    │   NIVEL 3: ARK  │
                    │  Microframework │
                    │     Global      │
                    └────────┬────────┘
                             │
                    ┌────────▼─────────┐
                    │  NIVEL 2: AEGIS  │  ← ESTÁS AQUÍ
                    │  CLI/TUI         │
                    │  Framework       │
                    └────┬─────┬───────┘
                         │     │
           ┌─────────────┘     └─────────────┐
           │                                  │
    ┌──────▼────────┐              ┌─────────▼──────┐
    │ NIVEL 1A:     │              │ NIVEL 1B:      │
    │ AURORA        │              │ ARGOS       │
    │ Formatting &  │              │ Execution &    │
    │ Rendering     │              │ Orchestration  │
    └───────────────┘              └────────────────┘
         BASE                           BASE
    (sin deps)                      (sin deps)
  ```

  ## Configuración

  Puedes configurar el terminal preferido:

      config :aegis, :terminal_backend, :iterm2  # :kitty, :tmux, o :iterm2
  """

  # Mensajes con colores
  @doc "Muestra un mensaje de éxito"
  defdelegate success(msg), to: Aegis.Printer

  @doc "Muestra un mensaje de error"
  defdelegate error(msg), to: Aegis.Printer

  @doc "Muestra un mensaje de advertencia"
  defdelegate warning(msg), to: Aegis.Printer

  @doc "Muestra un mensaje informativo"
  defdelegate info(msg), to: Aegis.Printer

  @doc "Muestra un mensaje de debug"
  defdelegate debug(msg), to: Aegis.Printer

  @doc "Muestra un mensaje de aviso"
  defdelegate notice(msg), to: Aegis.Printer

  @doc "Muestra un mensaje crítico"
  defdelegate critical(msg), to: Aegis.Printer

  @doc "Muestra una alerta"
  defdelegate alert(msg), to: Aegis.Printer

  @doc "Muestra un mensaje de emergencia"
  defdelegate emergency(msg), to: Aegis.Printer

  # Formato y presentación
  @doc "Muestra un mensaje con formato personalizado"
  defdelegate message(opts), to: Aegis.Printer

  @doc "Muestra un separador visual"
  defdelegate separator(opts \\ []), to: Aegis.Printer

  @doc "Muestra un encabezado con formato"
  defdelegate header(texts, opts \\ []), to: Aegis.Printer

  @doc "Muestra un subencabezado"
  defdelegate semiheader(text, opts \\ []), to: Aegis.Printer

  @doc "Muestra una tabla con formato"
  defdelegate table(headers, rows, opts \\ []), to: Aegis.Printer

  @doc "Muestra una pregunta y espera respuesta"
  defdelegate question(text, color \\ :primary, align \\ :left), to: Aegis.Printer

  @doc "Muestra una confirmación sí/no"
  defdelegate yesno(text, color \\ :primary, align \\ :left), to: Aegis.Printer

  @doc "Limpia la pantalla"
  defdelegate clear_screen(), to: Aegis.Printer

  # Animaciones
  @doc "Inicia una animación de carga"
  defdelegate start_animation(messages, align \\ :left), to: Aegis.Animation, as: :start

  @doc "Detiene la animación"
  defdelegate stop_animation(), to: Aegis.Animation, as: :stop

  # Terminal
  @doc "Obtiene el ancho de la terminal"
  defdelegate terminal_width(size \\ :full), to: Aegis.Terminal

  @doc "Obtiene el tamaño de la terminal"
  defdelegate terminal_size(), to: Aegis.Terminal

  @doc "Crea una pestaña de terminal"
  defdelegate create_tab(opts), to: Aegis.Terminal

  @doc "Crea un layout de servicios Trus"
  defdelegate create_trus_services_layout(tab_name, services), to: Aegis.Terminal

  # TUI
  @doc "Muestra un menú interactivo"
  def show_menu(options, _opts \\ []) do
    Aegis.Tui.run(options)
  end
end
