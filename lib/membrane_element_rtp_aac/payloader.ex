defmodule Membrane.RTP.AAC.Payloader do
  @moduledoc "TODO"

  use Membrane.Filter

  alias Membrane.Buffer
  alias Membrane.{AAC, RTP}
  alias Membrane.RTP.AAC.Utils

  def_input_pad :input, accepted_format: %AAC{encapsulation: :none}
  def_output_pad :output, accepted_format: %RTP{}

  def_options bitrate: [
                spec: :lbr | :hbr
              ],
              frames_per_packet: [
                spec: pos_integer()
              ]

  @impl true
  def handle_init(_ctx, options) do
    state =
      options
      |> Map.from_struct()
      |> Map.put(:acc, [])

    {_actions = [], state}
  end

  @impl true
  def handle_stream_format(:input, _stream_fmt, _ctx, state) do
    {[stream_format: {:output, %RTP{}}], state}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {[demand: {:input, size}], state}
  end

  @impl true
  def handle_buffer(:input, buffer, _ctx, state) do
    @type buffer.payload :: binary()
    acc = [buffer.payload | state.acc]

    if length(acc) == state.frames_per_packet do
      {[buffer: {:output, %Buffer{buffer | payload: wrap_aac(acc, state)}}], %{state | acc: []}}
    else
      {[], %{state | acc: acc}}
    end
  end

  @spec wrap_aac([binary()], map()) :: binary()
  defp wrap_aac(aus, state) do
    au_sizes = aus |> Enum.map(&byte_size/1)
    Utils.make_headers(au_sizes, state.bitrate) <> :binary.list_to_bin(aus)
  end
end
