#!/usr/bin/env elixir

# Script to fix common Credo issues automatically
defmodule CredoFixer do
  def fix_all do
    IO.puts("Fixing Credo issues in Aegis...")

    # Get all .ex files
    Path.wildcard("lib/**/*.ex")
    |> Enum.each(&fix_file/1)

    IO.puts("Done!")
  end

  def fix_file(file_path) do
    IO.puts("Fixing #{file_path}")

    content = File.read!(file_path)

    fixed_content = content
    |> fix_parentheses_on_zero_arity()
    |> fix_alias_ordering()

    File.write!(file_path, fixed_content)
  end

  # Fix "Do not use parentheses when defining a function which has no arguments"
  def fix_parentheses_on_zero_arity(content) do
    content
    |> String.replace(~r/def\s+(\w+)\(\),\s*do:/, "def \\1, do:")
    |> String.replace(~r/defp\s+(\w+)\(\),\s*do:/, "defp \\1, do:")
  end

  # Fix alias ordering within groups (simplified version)
  def fix_alias_ordering(content) do
    # This would need more complex logic for proper alias sorting
    # For now, just a placeholder
    content
  end
end

CredoFixer.fix_all()