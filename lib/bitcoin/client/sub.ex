defmodule Bitcoin.Client.Sub do
  use GenServer

  alias __MODULE__, as: State

  defstruct [endpoint: nil, context: nil, socket: nil, controlling_process: nil, msg_state: nil, queue: :queue.new()]

  @endpoints [:block, :transaction, :heartbeat, :radar]
  @queue_size 100

  @type endpoints :: :block | :transaction | :heartbeat | :radar

  @spec heartbeat(:http_uri.uri) :: GenServer.on_start
  def heartbeat(uri), do: start_link(:heartbeat, uri)

  @spec block(:http_uri.uri) :: GenServer.on_start
  def block(uri), do: start_link(:block, uri)

  @spec transaction(:http_uri.uri) :: GenServer.on_start
  def transaction(uri), do: start_link(:transaction, uri)

  @spec radar(:http_uri.uri) :: GenServer.on_start
  def radar(uri), do: start_link(:radar, uri)

  @spec controlling_process(pid, pid) :: :ok | {:error, term}
  def controlling_process(sub, process \\ self) do
    GenServer.call(sub, {:controlling_process, process})
  end

  def stream(sub, fun) do
    #receive do; {:radar, :tx, txid} -> IO.puts(txid |> String.reverse |> Base.encode16 case: :lower); Bitcoin.Client.Sub.ack_message(p); end
  end

  @spec ack_message(pid) :: :ok
  def ack_message(sub, process \\ self) do
    GenServer.cast(sub, {:ack_message, process})
  end

  @spec start_link(endpoints, :http_uri.uri) :: GenServer.on_start
  def start_link(endpoint, uri) when endpoint in @endpoints do
    GenServer.start_link(State, [endpoint, uri])
  end

  def init([endpoint, uri]) do
  #  endpoint = :radar
  #  {:ok, p} = Bitcoin.Client.Sub.radar 'tcp://45.32.235.141:7678'

    {:ok, ctx} = :czmq.start_link
    socket = :czmq.zsocket_new ctx, :sub
    :ok = :czmq.zsocket_connect socket, uri
    :ok = :czmq.zsocket_set_subscribe socket, ''
    {:ok, sub} = :czmq.subscribe_link socket, poll_interval: 100
    {:ok, %State{endpoint: endpoint, context: ctx, socket: sub}}
  end

  def handle_call({:controlling_process, process}, _from, state) do
    ref = Process.monitor(process)
    {:reply, :ok, %State{state | msg_state: :ready, controlling_process: {ref, process}}}
  end

  def handle_cast({:ack_message, process},
    %State{msg_state: :need_ack, queue: queue, controlling_process: {_ref, process}} = state) do
    case :queue.out(queue) do
      {{:value, message}, queue} ->
        state = %State{state | queue: queue, msg_state: :ready}
        {:ok, state} = send_to_controller(message, state)
        {:noreply, state}
      {:empty, queue} ->
        {:noreply, %State{state | queue: queue, msg_state: :ready}}
    end
  end
  def handle_cast({:ack_message, process}, state) do
    IO.inspect :other
    {:noreply, state}
  end

  def handle_info({:zmq, ctx, <<heart :: little-unsigned-integer-size(32) >>, _extra},
    %State{endpoint: :heartbeat} = state) do
    IO.inspect {:heart, heart}
    {:noreply, state}
  end
  def handle_info({:zmq, payload, _extra},
    %State{endpoint: :block, context: ctx} = state) do

    IO.inspect {:block, payload}
    {:noreply, state}
  end
  def handle_info({:zmq, payload, _extra},
    %State{endpoint: :transaction, context: ctx} = state) do
    IO.inspect {:transaction, payload}
    {:noreply, state}
  end
  def handle_info({socket, _msg}, %State{socket: socket, controlling_process: nil} = state) do
    # st
    {:noreply, state}
  end
  def handle_info({socket, [<<node_id :: little-integer-unsigned-size(32)>>,
    <<1 ::  little-integer-unsigned-size(32)>>, <<hash :: binary-size(32)>>] = payload},
    %State{endpoint: :radar, socket: socket} = state) do
      #    IO.inspect "#{node_id} #{Base.encode16(String.reverse(hash), case: :lower)}"
    {:ok, state} = send_to_controller {:radar, :tx, hash}, state
    {:noreply, state}
  end
  def handle_info({socket, [<<node_id :: little-integer-unsigned-size(32)>>,
    <<2 ::  little-integer-unsigned-size(32)>>, <<hash :: binary>>] = payload},
    %State{endpoint: :radar, socket: socket} = state) do
      #    IO.inspect "#{node_id} #{Base.encode16(String.reverse(hash), case: :lower)}"
    {:ok, state} = send_to_controller {:radar, :block, hash}, state
    {:noreply, state}
  end

  def send_to_controller(message, %State{controlling_process: nil} = state), do: {:ok, state}
  def send_to_controller(message, %State{msg_state: :ready, controlling_process: {_ref, controlling_process}} = state) do
    ^message = send controlling_process, message
    {:ok, %State{state| msg_state: :need_ack}}
  end
  def send_to_controller(message, %State{msg_state: :need_ack, queue: queue, controlling_process: {_ref, controlling_process}} = state) do
    queue = :queue.in_r(message, queue)
    queue = case :queue.len(queue) do
      n when n > @queue_size ->
        {queue, _tail} = :queue.split(@queue_size, queue)
        queue
      _n ->
        queue
    end
    {:ok, %State{state | queue: queue}}
  end

  #  def handle_info(evt, state) do
    #   IO.inspect {:info, evt}
    #  {:noreply, state}
    # end

end
