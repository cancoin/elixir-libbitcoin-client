defmodule Libbitcoin.Client.Sub do
  use GenServer

  alias __MODULE__, as: State

  defstruct [endpoint: nil, context: nil, socket: nil, sub: nil,
             controlling_process: nil, msg_state: nil, queue: :queue.new()]

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

  @spec ack_message(pid) :: :ok
  def ack_message(sub, process \\ self) do
    GenServer.cast(sub, {:ack_message, process})
  end

  @spec start_link(endpoints, :http_uri.uri) :: GenServer.on_start
  def start_link(endpoint, uri) when endpoint in @endpoints do
    GenServer.start_link(State, [endpoint, uri])
  end

  def init([endpoint, uri]) do
    {:ok, ctx} = :czmq.start_link
    socket = :czmq.zsocket_new ctx, :sub
    :ok = :czmq.zsocket_connect socket, uri
    :ok = :czmq.zsocket_set_subscribe socket, ''
    {:ok, sub} = :czmq_poller.start_link socket, poll_interval: 100
    schedule_resubscribe!
    {:ok, %State{endpoint: endpoint, context: ctx, socket: socket, sub: sub}}
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
  def handle_cast({:ack_message, _process}, state) do
    {:noreply, state}
  end

  def handle_info({sub, [<<heart :: little-unsigned-integer-size(32) >>]}, %State{endpoint: :heartbeat, sub: sub} = state) do
    {:ok, state} = send_to_controller {:libbitcoin_client, :heartbeat, heart}, state
    {:noreply, state}
  end
  def handle_info({sub, [tx]}, %State{endpoint: :transaction, sub: sub} = state) do
    {:ok, state} = send_to_controller {:libbitcoin_client, :transaction, tx}, state
    {:noreply, state}
  end
  def handle_info({sub, [<<height :: unsigned-little-size(32)>>, header | txids] = block}, %State{endpoint: :block, sub: sub} = state) do
    {:ok, state} = send_to_controller {:libbitcoin_client, :block, {height, header, txids}}, state
    {:noreply, state}
  end
  def handle_info({sub, [<<node_id :: little-integer-unsigned-size(32)>>,
    <<1 ::  little-integer-unsigned-size(32)>>, <<hash :: binary-size(32)>>]},
    %State{endpoint: :radar, sub: sub} = state) do
    {:ok, state} = send_to_controller {:libbitcoin_client, :transaction_radar, node_id, String.reverse(hash)}, state
    {:noreply, state}
  end
  def handle_info({sub, [<<node_id :: little-integer-unsigned-size(32)>>,
    <<2 ::  little-integer-unsigned-size(32)>>, <<hash :: binary>>]},
    %State{endpoint: :radar, sub: sub} = state) do
    {:ok, state} = send_to_controller {:libbitcoin_client, :block_radar, node_id, String.reverse(hash)}, state
    {:noreply, state}
  end
  def handle_info({:resubscribe, prefix}, %State{socket: socket} = state) do
    :ok = :czmq.zsocket_set_unsubscribe socket, prefix
    :ok = :czmq.zsocket_set_subscribe socket, prefix
    schedule_resubscribe!
    {:noreply, state}
  end
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:ok, %State{state | controlling_process: nil}}
  end

  def send_to_controller(_message, %State{controlling_process: nil} = state), do: {:ok, state}
  def send_to_controller(message, %State{msg_state: :ready, controlling_process: {_ref, controlling_process}} = state) do
    send controlling_process, message
    {:ok, %State{state| msg_state: :need_ack}}
  end
  def send_to_controller(message, %State{msg_state: :need_ack, queue: queue, controlling_process: {_ref, _controlling_process}} = state) do
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

  def schedule_resubscribe! do
    :erlang.send_after(5000, self, {:resubscribe, ''})
  end

end
