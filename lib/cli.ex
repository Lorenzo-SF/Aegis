defmodule Aegis.CLI do
  @moduledoc """
  Command-line interface for Aegis CLI/TUI framework.

  Provides functionality for colorful terminal output, tables, messages, and more.
  """
  alias Aegis.Printer

  @doc """
  Main entry point for Aegis CLI commands.
  """
  def main(argv) do
    argv
    |> parse_args()
    |> process_args()
  end

  defp parse_args(argv) do
    case OptionParser.parse(argv,
           strict: [
             color: :string,
             align: :string,
             headers: :string,
             rows: :string,
             compact: :boolean,
             version: :boolean
           ],
           aliases: [
             c: :color,
             a: :align,
             v: :version
           ]
         ) do
      {opts, args, _errors} ->
        {opts, args}
    end
  end

  defp process_args({opts, args}) do
    command = List.first(args)

    case command do
      "success" ->
        success_command(args)

      "error" ->
        error_command(args)

      "warning" ->
        warning_command(args)

      "info" ->
        info_command(args)

      "debug" ->
        debug_command(args)

      "table" ->
        table_command(opts, args)

      "header" ->
        header_command(args)

      "separator" ->
        separator_command()

      "question" ->
        question_command(args)

      "confirm" ->
        confirm_command(args)

      "animate" ->
        animate_command(args)

      "clear" ->
        clear_command()

      "version" ->
        version()

      nil ->
        show_help()

      _ ->
        show_help()
    end
  end

  # Success message command
  defp success_command(args) do
    message =
      case args do
        [_head | tail] -> Enum.join(tail, " ")
        [] -> ""
      end

    if message != "" do
      Printer.success(message)
    else
      IO.puts("Error: Missing message for success command")
      show_help()
    end
  end

  # Error message command
  defp error_command(args) do
    message =
      case args do
        [_head | tail] -> Enum.join(tail, " ")
        [] -> ""
      end

    if message != "" do
      Printer.error(message)
    else
      IO.puts("Error: Missing message for error command")
      show_help()
    end
  end

  # Warning message command
  defp warning_command(args) do
    message =
      case args do
        [_head | tail] -> Enum.join(tail, " ")
        [] -> ""
      end

    if message != "" do
      Printer.warning(message)
    else
      IO.puts("Error: Missing message for warning command")
      show_help()
    end
  end

  # Info message command
  defp info_command(args) do
    message =
      case args do
        [_head | tail] -> Enum.join(tail, " ")
        [] -> ""
      end

    if message != "" do
      Printer.info(message)
    else
      IO.puts("Error: Missing message for info command")
      show_help()
    end
  end

  # Debug message command
  defp debug_command(args) do
    message =
      case args do
        [_head | tail] -> Enum.join(tail, " ")
        [] -> ""
      end

    if message != "" do
      Printer.debug(message)
    else
      IO.puts("Error: Missing message for debug command")
      show_help()
    end
  end

  # Table command
  defp table_command(opts, _args) do
    headers_str = opts[:headers]
    rows_str = opts[:rows]

    if headers_str && rows_str do
      headers = String.split(headers_str, ",")

      rows =
        rows_str
        |> String.split(";")
        |> Enum.map(fn row -> String.split(row, ",") end)

      Printer.table(headers, rows)
    else
      IO.puts("Error: Missing headers or rows for table command")
      show_help()
    end
  end

  # Header command
  defp header_command(args) do
    text =
      case args do
        [_head | tail] -> Enum.join(tail, " ")
        [] -> ""
      end

    if text != "" do
      Printer.header([text])
    else
      IO.puts("Error: Missing text for header command")
      show_help()
    end
  end

  # Separator command
  defp separator_command() do
    Printer.separator()
  end

  # Question command
  defp question_command(args) do
    text =
      case args do
        [_head | tail] -> Enum.join(tail, " ")
        [] -> ""
      end

    if text != "" do
      # Since this is CLI context, just print the question
      Printer.question(text)
    else
      IO.puts("Error: Missing message for question command")
      show_help()
    end
  end

  # Confirm (yesno) command
  defp confirm_command(args) do
    text =
      case args do
        [_head | tail] -> Enum.join(tail, " ")
        [] -> ""
      end

    if text != "" do
      # Since this is CLI context, just print the confirmation
      Printer.yesno(text)
    else
      IO.puts("Error: Missing text for confirm command")
      show_help()
    end
  end

  # Animate command
  defp animate_command(args) do
    text =
      case args do
        [_head | tail] -> Enum.join(tail, " ")
        [] -> ""
      end

    if text != "" do
      # Start animation and exit immediately in CLI context
      Printer.animation([{text, :primary}])
    else
      IO.puts("Error: Missing text for animate command")
      show_help()
    end
  end

  # Clear command
  defp clear_command() do
    Terminal.clear_screen()
  end

  defp show_help() do
    help_text = """
    Aegis CLI - CLI/TUI framework for colorful terminal output

    Usage:
      aegis [COMMAND] [OPTIONS] [ARGUMENTS]

    Commands:
      success   Display a success message
                Usage: aegis success "Operation completed"

      error     Display an error message
                Usage: aegis error "An error occurred"

      warning   Display a warning message
                Usage: aegis warning "This is a warning"

      info      Display an info message
                Usage: aegis info "Processing information"

      debug     Display a debug message
                Usage: aegis debug "Debug information"

      table     Display a formatted table
                Usage: aegis table --headers "Name,Age,City" --rows "John,30,Madrid;Ana,25,Barcelona"

      header    Display a formatted header
                Usage: aegis header "Welcome to Aegis"

      separator Display a visual separator
                Usage: aegis separator

      question  Display a question (in CLI context just prints)
                Usage: aegis question "Are you sure?"

      confirm   Display a yes/no confirmation (in CLI context just prints)
                Usage: aegis confirm "Continue?"

      animate   Start an animation (in CLI context just starts)
                Usage: aegis animate "Loading..."

      clear     Clear the screen
                Usage: aegis clear

    Options:
      -c, --color COLOR     Color name (primary, error, success, etc.)
      -a, --align ALIGN     Alignment (left, right, center)
          --headers         Comma-separated column headers for table
          --rows            Semicolon-separated rows for table, with comma-separated values
    """

    IO.puts(help_text)
  end

  def version do
    config = Mix.Project.config()
    IO.puts("#{config[:app]} v#{config[:version]}")
  end
end
