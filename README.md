# Aegis

**CLI/TUI Framework para Elixir** - Nivel 2 de Proyecto Ypsilon

[![Version](https://img.shields.io/hexpm/v/aegis.svg)](https://hex.pm/packages/aegis) [![License](https://img.shields.io/hexpm/l/aegis.svg)](https://github.com/usuario/aegis/blob/main/LICENSE)

Aegis es un framework completo para crear interfaces de línea de comandos hermosas e interactivas con menús, animaciones, y control avanzado de terminal.

## Arquitectura

Aegis forma parte de **Proyecto Ypsilon**:

```
                    ┌─────────────────┐
                    │   NIVEL 3: ARK  │
                    │  Microframework │
                    │     Global      │
                    └────────┬────────┘
                             │
                    ┌────────▼─────────┐
                    │  NIVEL 2: AEGIS  │
                    │  CLI/TUI         │  ← ESTÁS AQUÍ
                    │  Framework       │
                    └────┬─────┬───────┘
                         │     │
           ┌─────────────┘     └─────────────┐
           │                                 │
    ┌──────▼────────┐              ┌─────────▼──────┐
    │ NIVEL 1A:     │              │ NIVEL 1B:      │
    │ AURORA        │              │ ARGOS          │
    │ Formatting &  │              │ Execution &    │
    │ Rendering     │              │ Orchestration  │
    └───────────────┘              └────────────────┘
         BASE                              BASE
      (sin deps).                       (sin deps)
```

## Características

- 🎨 **Sistema de impresión** con colores, tablas, y estilos
- 📋 **Menús interactivos** con selección múltiple
- 🌀 **Animaciones y spinners**
- 💻 **Control de terminal** (Kitty, Tmux, iTerm2)
- 🌐 **Integración con Aurora** (formatting) y **Argos** (execution)

## Instalación

Agrega a tu `mix.exs`:

```elixir
def deps do
  [
    {:aegis, "~> 1.0.0"}
  ]
end
```

## Uso Rápido

### Mensajes con colores

```elixir
Aegis.success("Operación completada")
Aegis.error("Algo salió mal")
Aegis.warning("Ten cuidado")
Aegis.info("Procesando...")
```

### Tablas y encabezados

```elixir
headers = ["Nombre", "Edad", "Ciudad"]
rows = [
  ["Juan", "30", "Madrid"],
  ["Ana", "25", "Barcelona"]
]

Aegis.table(headers, rows)
Aegis.header(["Bienvenido", "Sistema de Usuarios"])
```

### Menús interactivos

```elixir
options = [
  %{id: 1, name: "Opción 1", action: fn -> IO.puts("Seleccionaste 1") end},
  %{id: 2, name: "Opción 2", action: fn -> IO.puts("Seleccionaste 2") end}
]

Aegis.Tui.run(options)
```

### Animaciones

```elixir
Aegis.start_animation([{"Cargando...", :primary}])
# Hacer trabajo
Aegis.stop_animation()
```

### Control de Terminal

```elixir
# Crear pestaña en Kitty/Tmux
Aegis.create_tab(tab_id: "backend", command: "mix phx.server")

# Autoresize de terminal
Aegis.autoresize(120, 40)
```

## API Principal

### Mensajes

- `Aegis.success/1` - Mensaje de éxito
- `Aegis.error/1` - Mensaje de error
- `Aegis.warning/1` - Mensaje de advertencia
- `Aegis.info/1` - Mensaje informativo

### Formato

- `Aegis.header/2` - Encabezado con colores
- `Aegis.table/3` - Tabla con formato
- `Aegis.separator/1` - Separador visual

### Interacción

- `Aegis.question/3` - Pregunta al usuario
- `Aegis.yesno/3` - Confirmación sí/no
- `Aegis.Tui` - Sistema completo de menús

## Configuración

Puedes configurar el terminal preferido:

```elixir
# config/config.exs
config :aegis, :terminal_backend, :iterm2  # :kitty, :tmux, o :iterm2
```

## Módulos Principales

- `Aegis.Printer` - Sistema de impresión
- `Aegis.Animation` - Animaciones y spinners
- `Aegis.Terminal` - Control de terminal
- `Aegis.Tui` - Sistema TUI

## Uso como CLI

Aegis también puede usarse como una herramienta de línea de comandos independiente:

```bash
# Mostrar mensaje de éxito
aegis success "Operación completada"

# Mostrar mensaje de error
aegis error "Ha ocurrido un error"

# Mostrar mensaje de advertencia
aegis warning "Advertencia importante"

# Mostrar tabla formateada
aegis table --headers "Nombre,Edad,Ciudad" --rows "Juan,30,Madrid;Ana,25,Barcelona"

# Mostrar encabezado
aegis header "Bienvenido al Sistema"
```

## Licencia

Apache 2.0 - Consulta el archivo [LICENSE](LICENSE) para más detalles.
