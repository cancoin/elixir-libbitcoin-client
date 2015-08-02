defmodule Bitcoin.Client do
  alias Bitcoin.Client

  @max_uint32 4294967295
  @default_timeout 2000
  @hz 10

  defstruct [context: nil, socket: nil, requests: %{}, timeout: 1000]

  def last_height(client, owner \\ self) do
    cast(client, "blockchain.fetch_last_height", "", owner)
  end

  def block_height(client, block_hash, owner \\ self) do
    cast(client, "blockchain.fetch_block_height", encode_hash(block_hash), owner)
  end

  def block_header(client, height, owner \\ self) when is_integer(height) do
    cast(client, "blockchain.fetch_block_header", encode_int(height))
  end

  def block_transaction_hashes(client, hash, owner \\ self) do
    cast(client, "blockchain.fetch_block_transaction_hashes", encode_hash(hash))
  end

  def blockchain_transaction(client, txid, owner \\ self) do
    cast(client, "blockchain.fetch_transaction", encode_hash(txid), owner)
  end

  def pool_transaction(client, txid, owner \\ self) do
    cast(client, "transaction_pool.fetch_transaction", encode_hash(txid), owner)
  end

  def transaction_index(client, txid, owner \\ self) do
    cast(client, "blockchain.fetch_transaction_index", encode_hash(txid), owner)
  end

  def spend(client, txid, index, owner \\ self) do
    cast(client, "blockchain.fetch_spend", encode_hash(txid) <> encode_int(index))
  end

  def address_history(client, address, height \\ 0,  owner \\ self) do
    {prefix, decoded} = decode_base58check(address)
    cast(client, "address.fetch_history", <<prefix :: binary-size(1), encode_hash(decoded) :: binary-size(20), encode_int(height) :: binary>>, owner)
  end

  def address_history2(client, address, height \\ 0,  owner \\ self) do
    {prefix, decoded} = decode_base58check(address)
    cast(client, "address.fetch_history2",<<prefix :: binary-size(1), decoded :: binary-size(20), encode_int(height) :: binary>>, owner)
  end

  def blockchain_history(client, address, height \\ 0,  owner \\ self) do
    {prefix, decoded} = decode_base58check(address)
    cast(client, "blockchain.fetch_history", <<prefix :: binary-size(1), decoded :: binary-size(20), encode_int(height) :: binary>>, owner)
  end

  def start_link(uri, timeout \\ @default_timeout) do
    GenServer.start_link(__MODULE__, [uri, timeout])
  end

  def init([uri, timeout]) do
    {:ok, ctx} = :czmq.start_link
    socket = :czmq.zsocket_new ctx, :dealer
    :ok = :czmq.zctx_set_linger ctx, 0
    case :czmq.zsocket_connect socket, uri do
      :ok ->
        {:ok, %Client{context: ctx, socket: socket, timeout: timeout}}
      {:error, _} = error ->
        {:stop, error}
    end
  end

  def handle_cast({:command, request_id, command, argv, owner}, state) do
    {:ok, state} = state = add_request(request_id, owner, state)
    case send_command(request_id, command, argv, state) do
      {:ok, state} ->
        {:noreply, state}
      {:error, error, %Client{requests: requests} = state} ->
        :ok = send_reply({:error, error}, command, request_id, owner)
        {:ok, requests} = clear_request(request_id, requests)
        {:ok, state} = retry_receive_payload(%Client{state | requests: requests})
        {:noreply, state}
    end
  end

  def handle_info(:receive_payload, state) do
    case receive_payload(state) do
      {:ok, state} -> {:noreply, state}
    end
  end

  def handle_info({:timeout, request_id}, %Client{requests: requests} = state) do
    case Map.fetch(requests, request_id) do
      :error ->
        {:noreply, state}
      {:ok, owner} when is_pid(owner) ->
        send_reply({:error, :timeout}, nil, request_id, owner) 
        {:ok, requests} = clear_request(request_id, requests)
        {:noreply, %Client{state | requests: requests}}
    end
  end

  def handle_info(evt, state) do
    IO.inspect {:info, evt}
    {:noreply, state}
  end

  defp cast(client, command, argv, owner \\ self) do
    request_id = new_request_id
    case GenServer.cast(client, {:command, request_id, command, argv, owner}) do
      :ok -> {:ok, request_id}
      other -> other
    end
  end

  defp send_command(request_id, command, payload, state) do
    send_payload(request_id, command, payload, state)
  end

  defp decode_command(_command, <<3 :: little-integer-unsigned-size(32), _rest :: binary>>) do
    {:error, :not_found}
  end
  defp decode_command(_command, <<error :: little-integer-unsigned-size(32), _rest :: binary>>) when error != 0 do
    {:error, error}
  end
  defp decode_command(command, <<0 :: little-integer-unsigned-size(32), height :: little-integer-unsigned-size(32)>> )
    when command in ["blockchain.fetch_last_height", "blockchain.fetch_block_height"] do
    {:ok, height}
  end
  defp decode_command("blockchain.fetch_block_header", <<0 :: little-integer-unsigned-size(32), header :: binary>> ) do
    {:ok, header}
  end
  defp decode_command("blockchain.fetch_block_transaction_hashes", <<0 :: little-integer-unsigned-size(32), hashes :: binary>> ) do
    {:ok, hashes}
  end
  defp decode_command(command, <<0 :: little-integer-unsigned-size(32), transaction :: binary>> )
    when command in ["blockchain.fetch_transaction", "transaction_pool.fetch_transaction"] do
    {:ok, transaction}
  end
  defp decode_command("blockchain.fetch_transaction_index",
    <<0 :: little-integer-unsigned-size(32), height :: little-integer-unsigned-size(32), index :: little-integer-unsigned-size(32)>>) do
    {:ok, {height, index}}
  end
  defp decode_command("blockchain.fetch_spend",
    <<5 :: little-integer-unsigned-size(32), _ :: binary>>) do
    {:error, :unspent}
  end
  defp decode_command("blockchain.fetch_spend",
    <<0 :: little-integer-unsigned-size(32), txid :: binary-size(32), index :: little-integer-unsigned-size(32)>>) do
    {:ok, {String.reverse(txid), index}}
  end
  defp decode_command("blockchain.fetch_history", <<0 :: little-integer-unsigned-size(32)>>) do
    {:ok, []}
  end
  defp decode_command("address.fetch_history", <<code :: little-integer-size(32), history :: binary>>) do
    decode_history1(history, [])
  end
  defp decode_command(command, <<code :: little-integer-size(32), history :: binary>>)
   when command in ["blockchain.fetch_history", "address.fetch_history2"] do
    decode_history2(history, [])
  end
  defp decode_command(any, reply) do
    {:error, :unknown_reply}
  end

  defp decode_history1(<<>>, acc), do: {:ok, Enum.reverse(acc)}
  defp decode_history1(<<output_hash :: binary-size(32),
                        output_index :: little-unsigned-integer-size(32),
                        output_height :: little-unsigned-integer-size(32),
                        value :: little-unsigned-integer-size(64),
                        spend_hash :: binary-size(32),
                        spend_index :: little-unsigned-integer-size(32),
                        spend_height :: little-unsigned-integer-size(32),
                        rest :: binary>>, acc) do

    row = %{output_hash: decode_hash(output_hash), output_index: output_index, output_height: output_height,
            value: value, spend_hash: decode_hash(spend_hash), spend_index: spend_index, spend_height: spend_height}
    decode_history1(rest, [row|acc])
  end

  defp decode_history2(<<>>, acc), do: {:ok, Enum.reverse(acc)}
  defp decode_history2(<<type :: binary-bytes-size(1),
                         hash :: binary-size(32),
                         index :: little-unsigned-integer-size(32),
                         height :: little-unsigned-integer-size(32),
                         value :: little-unsigned-integer-size(64),
                         rest :: binary>>, acc) do

    row = %{type: history_row_type(type), hash: decode_hash(hash), index: index, height: height, value: value}
    decode_history2(rest, [row|acc])
  end


  defp history_row_type(<<0>>), do: :output
  defp history_row_type(<<1>>), do: :spend

  defp send_payload(request_id, command, payload, %Client{socket: socket, context: ctx, timeout: timeout} = state) do
    bin_request_id = <<request_id :: unsigned-little-integer-size(32)>>
    _timerref = schedule_timeout(request_id, timeout)
    case :czmq.zsocket_send_all(socket, [command, bin_request_id, payload]) do
      :ok ->
        receive_payload(state)
      other ->
        other
    end
  end

  defp receive_payload(%Client{socket: socket} = state) do
    IO.inspect "r"
    case :czmq.zframe_recv_all(socket) do
      {:ok, reply} ->
        handle_reply(reply, state)
      :error ->
        retry_receive_payload(state)
    end
  end

  def add_request(request_id, owner, %Client{requests: requests} = state) do
    {:ok, %Client{state | requests: Map.put(requests, request_id, owner)}}
  end

  def clear_request(request_id, requests) do
    new_requests = Map.delete(requests, request_id)
    {:ok, new_requests}
  end

  defp handle_reply([command, <<request_id :: integer-little-unsigned-size(32)>>, reply], %Client{requests: requests} = state) do
    case Map.fetch(requests, request_id) do
      {:ok, owner} when is_pid(owner) ->
        decode_command(command, reply) |> send_reply(command, request_id, owner)
        {:ok, requests} = clear_request(request_id, requests)
        {:ok, %Client{state | requests: requests}}
      :error ->
        {:error, :not_found}
    end
  end

  def retry_receive_payload(%Client{requests: []} = state) do
    {:ok, state}
  end
  def retry_receive_payload(state) do
    :erlang.send_after(@hz, self, :receive_payload)
    {:ok, state}
  end

  def schedule_timeout(request_id, timeout) do
    :erlang.send_after(timeout, self, {:timeout, request_id})
  end

  def send_reply({:ok, decoded}, command, request_id, owner) do
    send(owner, {:bitcoin_client, command, request_id, decoded})
  end

  def send_reply({:error, reason}, command, request_id, owner) do
    send(owner, {:bitcoin_client_error, command, request_id, reason})
  end

  defp new_request_id, do: :erlang.unique_integer([:positive])

  defp encode_int(int), do: <<int :: little-integer-unsigned-size(32)>>

  defp decode_int(<<int :: little-integer-unsigned-size(32)>>), do: int

  defp encode_hash(hash) do
    encode_hash(hash, <<>>)
  end
  defp encode_hash(<<>>, acc), do: acc
  defp encode_hash(<<h :: binary-size(1), rest :: binary>>, acc) do
    encode_hash(rest, <<h :: binary, acc :: binary>>)
  end
  
  defp decode_hash(hash), do: Base.encode16(String.reverse(hash), case: :lower)

  def decode_base58check(address) do
    <<version::binary-size(1), pkh::binary-size(20), checksum::binary-size(4)>> = :base58.base58_to_binary(to_char_list(address))
    case  :crypto.hash(:sha256, :crypto.hash(:sha256, version <> pkh)) do
      <<^checksum :: binary-size(4), _ :: binary>> -> {version, (pkh)}
      _ -> {:error, :invalid_checksum}
    end
  end
end
