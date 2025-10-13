# Changelog

Todos los cambios notables a este proyecto se documentarán en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-11

### 🎉 Versión Inicial

Primera versión estable de Aegis como CLI/TUI Framework para Elixir.

### 🏗️ Arquitectura Base

- **Nivel 2 en Proyecto Ypsilon**
- **Dependencias**: Aurora (1A) + Argos (1B)
- **Sin dependencias circulares**
- **Framework completo para interfaces de terminal**

### 🎨 Sistema de Impresión

#### Mensajes con Colores

- `Aegis.success/1` - Mensajes de éxito
- `Aegis.error/1` - Mensajes de error
- `Aegis.warning/1` - Mensajes de advertencia
- `Aegis.info/1` - Mensajes informativos
- `Aegis.debug/1` - Mensajes de debug
- `Aegis.notice/1` - Mensajes de aviso
- `Aegis.critical/1` - Mensajes críticos
- `Aegis.alert/1` - Alertas
- `Aegis.emergency/1` - Mensajes de emergencia

#### Formato Avanzado

- `Aegis.message/1` - Mensajes con formato personalizado
- `Aegis.separator/1` - Separadores visuales
- `Aegis.header/2` - Encabezados formateados
- `Aegis.semiheader/2` - Subencabezados
- `Aegis.table/3` - Tablas con colores y alineación
- `Aegis.question/3` - Preguntas interactivas
- `Aegis.yesno/3` - Confirmaciones sí/no

#### Utilidades

- `Aegis.clear_screen/0` - Limpieza de pantalla
- `Aegis.start_animation/2` - Animaciones de carga
- `Aegis.stop_animation/0` - Detención de animaciones

### 📋 Sistema TUI

#### Menús Interactivos

- `Aegis.show_menu/2` - Visualización de menús interactivos
- `Aegis.Tui.MenuBuilder` - Constructor de menús avanzados
- `Aegis.Tui.Core` - Núcleo del sistema TUI
- `Aegis.Tui.InputHandler` - Manejo de entrada de usuario
- `Aegis.Tui.Renderer` - Renderizado de interfaces
- `Aegis.Tui.Terminal` - Control de terminal
- `Aegis.Tui.TaskRunner` - Ejecución de tareas con UI
- `Aegis.Tui.TreeNavigator` - Navegación por árboles
- `Aegis.Tui.LogoCache` - Cache de logos

### 💻 Control de Terminal

#### Sistema Unificado

- `Aegis.Terminal` - Interfaz unificada para todos los terminales
- Detección automática de ambiente (Kitty, Tmux, iTerm2)
- Selección configurable mediante `config :aegis, :terminal_backend`

#### Terminales Soportados

- `Aegis.Terminal.Kitty` - Control de terminal Kitty
- `Aegis.Terminal.Tmux` - Control de terminal Tmux
- `Aegis.Terminal.Iterm2` - Control de terminal iTerm2 (nuevo)

#### Funcionalidad Terminal

- `Aegis.create_window/1` - Creación de ventanas
- `Aegis.create_tab/1` - Creación de pestañas
- `Aegis.create_pane/1` - Creación de paneles
- `Aegis.send_command/1` - Envío de comandos
- `Aegis.close_element/1` - Cierre de elementos
- `Aegis.apply_styles/1` - Aplicación de estilos
- `Aegis.apply_layout/1` - Aplicación de layouts
- `Aegis.navigate_to/1` - Navegación entre elementos
- `Aegis.list_elements/1` - Listado de elementos
- `Aegis.find_element/1` - Búsqueda de elementos
- `Aegis.autoresize/2` - Auto-redimensionamiento
- `Aegis.terminal_size/0` - Obtención de tamaño de terminal
- `Aegis.terminal_width/1` - Obtención de ancho de terminal
- `Aegis.available?/0` - Verificación de disponibilidad

### 🌀 Sistema de Animaciones

- `Aegis.Animation` - Sistema de animaciones y spinners
- `Aegis.start_animation/2` - Inicio de animaciones
- `Aegis.stop_animation/0` - Detención de animaciones
- Animaciones personalizables con colores de Aurora

### 📦 Estructuras de Datos

#### MenuOption

```elixir
%Aegis.Structs.MenuOption{
  id: term(),                 # Identificador único
  name: String.t(),          # Nombre mostrado
  description: String.t(),    # Descripción
  action_type: atom(),        # Tipo de acción (:navigation, :execution)
  action: function() | atom(), # Acción a ejecutar
  args: list(),               # Argumentos para la acción
  data: term()                # Datos adicionales
}
```

#### PussyConfig (compatibilidad retroactiva)

```elixir
%Aegis.Structs.PussyConfig{
  window_id: String.t() | nil,
  tab_id: String.t() | nil,
  pane_id: String.t() | nil,
  command: String.t() | nil,
  orientation: :horizontal | :vertical | nil,
  layout: String.t() | nil,
  shell: String.t() | nil
}
```

### 🧪 Pruebas

- Suite completa de pruebas unitarias
- Cobertura de código > 80%
- Tests de integración para funcionalidades principales
- Tests para diferentes ambientes de terminal

### 📚 Documentación

- README.md completo con ejemplos prácticos
- Documentación en línea para todas las funciones públicas
- Guía de uso para diferentes componentes
- Integración con `mix docs`

## [0.1.0] - 2025-10-10

### 🚀 Versión Alpha Inicial

Primera versión alpha de Aegis como parte del refactor de Proyecto Ypsilon.

### 🏗️ Estructura Inicial

- Migración de funcionalidad desde Pandr
- Reorganización en módulos especializados
- Integración con nueva arquitectura de dependencias

### 🛠️ Funcionalidad Básica

- Sistema de impresión básico con colores
- Menús interactivos iniciales
- Control de terminal básico (antes Pussycat)

## Versión 1.0.3 (2025-09-26)

### 🔧 Refactoring

- Refactor y fix de Printer. Actualizacion de documentación

## Versión 1.0.2 (2025-09-25)

### 🔧 Refactoring

- Refactor nombres de funciones de "Animation"

## Versión 1.0.1 (2025-09-24)

### 

- Refactor de "Tui" porque en algunas ocasiones da problemas de compilacion

## Versión 1.0.0 (2025-09-24)

### 

- Publicacion libreria

[Unreleased]: https://github.com/usuario/aegis/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/usuario/aegis/releases/tag/v1.0.0