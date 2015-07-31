defmodule Bitcoin.Client.Sub do
  use GenServer

  alias __MODULE__, as: Sub

  defstruct [endpoint: nil, context: nil, socket: nil]

  @endpoints [:block, :transaction, :heartbeat]

  @type endpoints :: :block | :transaction | :heartbeat

  @spec heartbeat(:http_uri.uri) :: GenServer.on_start
  def heartbeat(uri), do: start_link(:heartbeat, uri)

  @spec block(:http_uri.uri) :: GenServer.on_start
  def block(uri), do: start_link(:block, uri)

  @spec transaction(:http_uri.uri) :: GenServer.on_start
  def transaction(uri), do: start_link(:transaction, uri)

  @spec controlling_process(pid, pid) :: :ok | {:error, term}
  def controlling_process(sub, process \\ self) do
    GenServer.call(sub, {:controlling_process, process})
  end

  @spec start_link(endpoints, :http_uri.uri) :: GenServer.on_start
  def start_link(endpoint, uri) when endpoint in @endpoints do
    GenServer.start_link(Sub, [endpoint, uri])
  end

  def init([endpoint, uri]) do
    {:ok, ctx} = :erlzmq.context
    {:ok, sub} = :erlzmq.socket ctx, [:sub, {:active, true}]
    :ok = :erlzmq.connect sub, uri
    :ok = :erlzmq.setsockopt sub, :subscribe, ""
    {:ok, %Sub{endpoint: endpoint, context: ctx, socket: sub}}
  end

  def handle_info({:zmq, ctx, <<heart :: little-unsigned-integer-size(32) >>, _extra},
    %Sub{endpoint: :heartbeat} = state) do

    IO.inspect {:heart, heart}
    {:noreply, state}
  end

  def handle_info({:zmq, payload, _extra},
    %Sub{endpoint: :transaction, context: ctx} = state) do

    IO.inspect {:transaction, payload}
    {:noreply, state}
  end

  def handle_info({:zmq, payload, _extra},
    %Sub{endpoint: :block, context: ctx} = state) do

    IO.inspect {:block, payload}
    {:noreply, state}
  end

  def handle_info(evt, state) do
    IO.inspect {:info, evt}
    {:noreply, state}
  end

end
