defmodule Aegis.TerminalTest do
  use ExUnit.Case, async: true
  alias Aegis.Terminal

  describe "terminal operations" do
    setup do
      # Configurar mocks para diferentes terminales
      :meck.new(Aegis.Terminal.Iterm2, [:passthrough])
      :meck.new(Aegis.Terminal.Kitty, [:passthrough])
      :meck.new(Aegis.Terminal.Tmux, [:passthrough])
      :meck.new(Aegis.Structs.PussyConfig, [:passthrough])
      
      on_exit(fn ->
        :meck.unload([Aegis.Terminal.Iterm2, Aegis.Terminal.Kitty, Aegis.Terminal.Tmux, Aegis.Structs.PussyConfig])
      end)

      :ok
    end

    test "clear_screen/0" do
      # Mockear la detección de terminal
      Process.put(:detected_terminal, :unknown)
      
      # Verificar que la función no genere errores
      assert :ok = Terminal.clear_screen()
    end

    test "autoresize/2" do
      # Mockear la detección de terminal
      Process.put(:detected_terminal, :unknown)
      
      # Verificar que la función no genere errores
      assert {:ok, "Auto-resize no soportado"} = Terminal.autoresize(300, 55)
    end

    test "create_tab/1 with iTerm2" do
      Process.put(:detected_terminal, :iterm2)
      
      # Configurar el mock para que devuelva un valor
      :meck.expect(Aegis.Terminal.Iterm2, :create_tab, fn _opts -> {:ok, "Tab created"} end)
      
      tab_config = %Aegis.Structs.PussyConfig{tab_id: "test_tab"}
      assert {:ok, "Tab created"} = Terminal.create_tab(tab_config)
    end

    test "create_tab/1 with Kitty" do
      Process.put(:detected_terminal, :kitty)
      
      :meck.expect(Aegis.Terminal.Kitty, :create_tab, fn _opts -> {:ok, "Kitty tab created"} end)
      
      tab_config = %Aegis.Structs.PussyConfig{tab_id: "test_tab"}
      assert {:ok, "Kitty tab created"} = Terminal.create_tab(tab_config)
    end

    test "create_tab/1 with Tmux" do
      Process.put(:detected_terminal, :tmux)
      
      :meck.expect(Aegis.Terminal.Tmux, :create_tab, fn _opts -> {:ok, "Tmux tab created"} end)
      
      tab_config = %Aegis.Structs.PussyConfig{tab_id: "test_tab"}
      assert {:ok, "Tmux tab created"} = Terminal.create_tab(tab_config)
    end

    test "create_window/1" do
      Process.put(:detected_terminal, :unknown)
      
      window_config = %Aegis.Structs.PussyConfig{window_id: "test_window"}
      result = Terminal.create_window(window_config)
      # Si no hay terminal detectado, debería usar fallback
      assert result
    end

    test "send_command/1" do
      Process.put(:detected_terminal, :unknown)
      
      command_config = %Aegis.Structs.PussyConfig{command: "echo 'test'"}
      result = Terminal.send_command(command_config)
      # Debería usar fallback
      assert result
    end

    test "navigate_to/1" do
      Process.put(:detected_terminal, :unknown)
      
      navigate_config = %Aegis.Structs.PussyConfig{window_id: "test_window"}
      result = Terminal.navigate_to(navigate_config)
      # Debería usar fallback
      assert result
    end

    test "create_pane/1" do
      Process.put(:detected_terminal, :unknown)
      
      pane_config = %Aegis.Structs.PussyConfig{pane_id: "test_pane"}
      assert {:ok, "Fallback: Pane no soportado"} = Terminal.create_pane(pane_config)
    end

    test "apply_layout/1" do
      Process.put(:detected_terminal, :unknown)
      
      layout_config = %Aegis.Structs.PussyConfig{window_id: "test_window"}
      result = Terminal.apply_layout(layout_config)
      # Debería usar fallback (probablemente nil)
      assert result
    end

    test "close_element/1" do
      Process.put(:detected_terminal, :unknown)
      
      tab_config = %Aegis.Structs.PussyConfig{tab_id: "test_tab"}
      assert {:ok, "Close element not supported"} = Terminal.close_element(tab_config)
    end

    test "send_command with specific config" do
      Process.put(:detected_terminal, :unknown)
      
      main_command_config = %Aegis.Structs.PussyConfig{command: "main_command"}
      result = Terminal.send_command(main_command_config)
      assert result
      
      index_command_config = %Aegis.Structs.PussyConfig{command: "index_command"}
      result = Terminal.send_command(index_command_config)
      assert result
    end
  end

  describe "fallback operations" do
    test "fallback_create_tab with Kitty" do
      # Mock para simular que estamos en Kitty
      :meck.new(Aegis.Terminal, [:passthrough])
      :meck.expect(Aegis.Terminal, :detected_terminal, fn -> :kitty end)
      
      on_exit(fn -> :meck.unload(Aegis.Terminal) end)
      
      # Esto probaría el fallback
      tab_config = %Aegis.Structs.PussyConfig{command: "ls"}
      result = Terminal.create_tab(tab_config)
      assert result
    end
  end

  describe "utility functions" do
    test "terminal_size/0" do
      {width, height} = Terminal.terminal_size()
      assert is_integer(width)
      assert is_integer(height)
    end

    test "terminal_width/1" do
      full_width = Terminal.terminal_width(:full)
      assert is_integer(full_width)
      
      half_width = Terminal.terminal_width(:half)
      assert is_integer(half_width)
      
      quarter_width = Terminal.terminal_width(:quarter)
      assert is_integer(quarter_width)
    end

    test "available?/0" do
      result = Terminal.available?()
      assert is_boolean(result)
    end
  end
end