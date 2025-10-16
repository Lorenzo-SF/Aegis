defmodule Aegis.Animation do
  @moduledoc """
  Provides terminal animation functionality with spinning frames and color support.

  This module allows for creating animated text in the terminal using various frames
  and colors. Animations run asynchronously and can be started and stopped as needed.

  ## Examples

      iex> Aegis.Animation.start([{"Loading...", :primary}], :left)
      :ok

      iex> Aegis.Animation.stop()
      :ok
  """

  alias Aurora.{Format, Normalize}
  alias Aurora.Structs.{ChunkText, FormatInfo}
  alias Argos.AsyncTask
  @frames Application.compile_env(:aegis, :animations)[:frames] ||
            ["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"]
  @interval Application.compile_env(:aegis, :animations)[:interval] || 100

  def frame_for(idx) do
    frame_idx = rem(System.system_time(:millisecond), div(@interval + idx, length(@frames)))
    Enum.at(@frames, frame_idx)
  end

  def start(messages, align \\ :left) do
    hide_cursor()
    IO.write("\e[s")

    chunks = Normalize.normalize_messages(messages)

    Argos.start_async_task(
      :animation_task,
      fn _ -> animate_loop(@frames, chunks, align) end,
      []
    )

    :ok
  end

  def stop do
    AsyncTask.stop(:animation_task)
    show_cursor()
    clear_line()
    IO.puts("")
    :ok
  end

  @doc """
  Starts an animation in raw mode with absolute positioning for terminal TUI applications.

  This function provides precise control over cursor positioning suitable for applications
  that manage the entire terminal screen in raw mode.

  ## Parameters
  - messages: List of messages to animate (same format as start/2)
  - x: Column position (1-based)
  - y: Row position (1-based)
  - align: Text alignment (:left, :center, :right) - default :left

  ## Examples
      iex> Aegis.Animation.start_raw([{"Loading...", :primary}], 10, 5)
      :ok

      iex> Aegis.Animation.start_raw([{"Processing", :info}], 20, 3, :center)
      :ok
  """
  def start_raw(messages, x, y, align \\ :left) do
    hide_cursor()

    chunks = Normalize.normalize_messages(messages)

    Argos.start_async_task(
      :animation_task_raw,
      fn _ -> animate_loop_raw(@frames, chunks, x, y, align) end,
      []
    )

    :ok
  end

  @doc """
  Stops the raw mode animation and cleans up the animation area.

  Unlike stop/0, this function doesn't add a newline and provides more precise
  cleanup suitable for TUI applications.
  """
  def stop_raw do
    AsyncTask.stop(:animation_task_raw)
    show_cursor()
    :ok
  end

  defp animate_loop(frames, chunks, align) do
    Stream.cycle(frames)
    |> Enum.each(fn frame_symbol ->
      frame(frame_symbol, chunks, align)
    end)
  end

  defp animate_loop_raw(frames, chunks, x, y, align) do
    Stream.cycle(frames)
    |> Enum.each(fn frame_symbol ->
      frame_raw(frame_symbol, chunks, x, y, align)
    end)
  end

  defp frame(frame_symbol, [%ChunkText{text: text} = head | tail], align) do
    updated_head = %ChunkText{head | text: "#{frame_symbol} #{text}"}

    formatted =
      Format.format(%FormatInfo{
        chunks: [updated_head | tail],
        align: align,
        add_line: :none,
        animation: "\e[u"
      })

    IO.write("\e[u\r[2K" <> formatted)
    :timer.sleep(@interval)
    :ok
  end

  defp frame(_frame, _chunks, _align), do: :ok

  defp frame_raw(frame_symbol, [%ChunkText{text: text} = head | tail], x, y, align) do
    updated_head = %ChunkText{head | text: "#{frame_symbol} #{text}"}

    formatted =
      Format.format(%FormatInfo{
        chunks: [updated_head | tail],
        align: align,
        add_line: :none
      })

    # Position cursor at absolute coordinates and clear the line
    IO.write("\e[#{y};#{x}H\e[2K" <> formatted)
    :timer.sleep(@interval)
    :ok
  end

  defp frame_raw(_frame, _chunks, _x, _y, _align), do: :ok

  def clear_line, do: IO.write("\e[2K\r")
  defp hide_cursor, do: IO.write("\e[?25l")
  defp show_cursor, do: IO.write("\e[?25h")
end
