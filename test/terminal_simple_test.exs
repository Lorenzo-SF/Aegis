defmodule Aegis.TerminalTest do
  use ExUnit.Case, async: true
  alias Aegis.Terminal

  describe "terminal operations" do
    test "clear_screen/0" do
      # Verificar que la función no genere errores
      result = Terminal.clear_screen()
      assert result
    end

    test "autoresize/2" do
      # Verificar que la función no genere errores después de nuestra corrección
      result = Terminal.autoresize(300, 55)
      assert result
    end

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

  describe "normalize_config function behavior" do
    test "should handle keyword lists correctly" do
      # Test with command keyword
      result = Aegis.Terminal.normalize_config([command: "ls -la"])
      assert result.__struct__ == Aegis.Structs.PussyConfig
      assert result.command == "ls -la"

      # Test without command keyword - should create PussyConfig with the provided options
      result = Aegis.Terminal.normalize_config([width: 100, height: 50])
      assert result.__struct__ == Aegis.Structs.PussyConfig
      assert result.width == 100
      assert result.height == 50
    end
  end
end