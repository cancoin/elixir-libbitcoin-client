defmodule Libbitcoin.Client do
  alias Libbitcoin.Client
  use Bitwise
  use Libbitcoin.Client.ErrorCode

  @default_timeout 2000
  @hz 10

  defstruct [context: nil, socket: nil, requests: %{}, timeout: 1000]

  def start_link(uri, options \\ %{}) do
    GenServer.start_link(__MODULE__, [uri, options])
  end

  def last_height(client, owner \\ self) do
    cast(client, "blockchain.fetch_last_height", "", owner)
  end

  def block_height(client, block_hash, owner \\ self) do
    cast(client, "blockchain.fetch_block_height", reverse_hash(block_hash), owner)
  end

  def block_header(client, height, owner \\ self) when is_integer(height) do
    cast(client, "blockchain.fetch_block_header", encode_int(height), owner)
  end

  def block_transaction_hashes(client, hash, owner \\ self) when is_binary(hash) do
    cast(client, "blockchain.fetch_block_transaction_hashes", reverse_hash(hash), owner)
  end

  def blockchain_transaction(client, txid, owner \\ self) do
    cast(client, "blockchain.fetch_transaction", reverse_hash(txid), owner)
  end

  def pool_transaction(client, txid, owner \\ self) do
    cast(client, "transaction_pool.fetch_transaction", reverse_hash(txid), owner)
  end

  def transaction_index(client, txid, owner \\ self) do
    cast(client, "blockchain.fetch_transaction_index", reverse_hash(txid), owner)
  end

  def spend(client, txid, index, owner \\ self) do
    cast(client, "blockchain.fetch_spend", reverse_hash(txid) <> encode_int(index), owner)
  end

  def stealth(client, bits, height \\ 0, owner \\ self) do
    bitfield = encode_stealth(bits)
    bitfield_size = byte_size(bitfield)
    size = byte_size(bits)
    cast(client, "blockchain.fetch_stealth",
      << size :: unsigned-integer-size(8),
         bitfield :: binary-size(bitfield_size),
         height :: unsigned-integer-size(32)>>, owner)
  end

  def address_history(client, address, height \\ 0,  owner \\ self) do
    {prefix, decoded} = decode_base58check(address)
    cast(client, "address.fetch_history",
      <<prefix :: binary-size(1),
        reverse_hash(decoded) :: binary-size(20),
        encode_int(height) :: binary>>, owner)
  end

  def address_history2(client, address, height \\ 0,  owner \\ self) do
    {prefix, decoded} = decode_base58check(address)
    cast(client, "address.fetch_history2",
      <<prefix :: binary-size(1),
        decoded :: binary-size(20),
        encode_int(height) :: binary>>, owner)
  end

  def blockchain_history(client, address, height \\ 0,  owner \\ self) do
    {prefix, decoded} = decode_base58check(address)
    cast(client, "blockchain.fetch_history",
      <<prefix :: binary-size(1),
        decoded :: binary-size(20),
        encode_int(height) :: binary>>, owner)
  end

  def blockchain_history3(client, address, height \\ 0,  owner \\ self) do
    {prefix, decoded} = decode_base58check(address)
    cast(client, "blockchain.fetch_history3",
      <<decoded :: binary-size(20),
        encode_int(height) :: binary>>, owner)
  end

  def total_connections(client, owner \\ self) do
    cast(client, "protocol.total_connections", "", owner)
  end

  def validate(client, tx, owner \\ self) do
    cast(client, "transaction_pool.validate", tx, owner)
  end

  def broadcast_transaction(client, tx, owner \\ self) do
    cast(client, "protocol.broadcast_transaction", tx, owner)
  end

  @divisor 1 <<< 63
  def spend_checksum(hash, index) do
    encoded_index = <<index :: little-unsigned-size(32)>>
    <<_ :: binary-size(4), hash_value :: binary-size(4), _ :: binary>> = reverse_hash(hash)
    encoded_value = <<encoded_index :: binary-size(4), hash_value :: binary-size(4)>>
    value = :binary.decode_unsigned(encoded_value, :little)
    value &&& (@divisor - 1)
  end

  def init([uri, %{timeout: timeout}]) do
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
  def init([uri, options]) do
    options = Map.merge(options, %{timeout: @default_timeout})
    init([uri, options])
  end

  def handle_cast({:command, request_id, command, argv, owner}, state) do
    {:ok, state} = add_request(request_id, owner, state)
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
      {:error, :not_found} -> {:noreply, state}
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

  defp cast(client, command, argv, owner) do
    request_id = new_request_id
    case GenServer.cast(client, {:command, request_id, command, argv, owner}) do
      :ok -> {:ok, request_id}
      reply -> reply
    end
  end

  defp send_command(request_id, command, payload, state) do
    case send_payload(request_id, command, payload, state) do
      :error -> {:error, :request_error, state}
      reply -> reply
    end
  end

  defp decode_command(_command, <<3 :: little-integer-unsigned-size(32), _rest :: binary>>) do
    {:error, :not_found}
  end
  defp decode_command(command,
    <<@success :: little-integer-unsigned-size(32), height :: little-integer-unsigned-size(32)>>)
    when command in ["blockchain.fetch_last_height", "blockchain.fetch_block_height"] do
    {:ok, height}
  end
  defp decode_command("blockchain.fetch_block_header",
    <<@success :: little-integer-unsigned-size(32), header :: binary>>) do
    {:ok, header}
  end
  defp decode_command("blockchain.fetch_block_transaction_hashes",
    <<@success :: little-integer-unsigned-size(32), hashes :: binary>>) do
    hashes = transform_block_transactions_hashes(hashes, [])
    {:ok, hashes}
  end
  defp decode_command(command,
    <<@success :: little-integer-unsigned-size(32), transaction :: binary>> )
    when command in ["blockchain.fetch_transaction", "transaction_pool.fetch_transaction"] do
    {:ok, transaction}
  end
  defp decode_command("blockchain.fetch_transaction_index",
    <<@success :: little-integer-unsigned-size(32),
      height :: little-integer-unsigned-size(32),
      index :: little-integer-unsigned-size(32)>>) do
    {:ok, {height, index}}
  end
  defp decode_command("blockchain.fetch_spend",
    <<@not_found :: little-integer-unsigned-size(32), _ :: binary>>) do
    {:error, error_code(5)}
  end
  defp decode_command("blockchain.fetch_spend",
    <<@success :: little-integer-unsigned-size(32), txid :: binary-size(32),
      index :: little-integer-unsigned-size(32)>>) do

    {:ok, {reverse_hash(txid), index}}
  end
  defp decode_command("blockchain.fetch_stealth", <<@success :: little-integer-unsigned-size(32)>>) do
    {:ok, []}
  end
  defp decode_command("blockchain.fetch_stealth", <<@success :: little-integer-size(32), rows :: binary>>) do
    decode_stealth(rows, [])
  end
  defp decode_command("address.fetch_history", <<@success :: little-integer-unsigned-size(32)>>) do
    {:ok, []}
  end
  defp decode_command("address.fetch_history",
    <<@success :: little-integer-size(32), history :: binary>>) do
    decode_history1(history, [])
  end
  defp decode_command(command, <<@success :: little-integer-size(32), history :: binary>>)
   when command in ["blockchain.fetch_history", "address.fetch_history2"] do
    decode_history2(history, [])
  end
  defp decode_command("blockchain.fetch_history3",
    <<@success :: little-integer-size(32), history :: binary>>) do
    decode_history2(history, [])
  end
  defp decode_command("transaction_pool.validate",
    <<ec :: little-integer-unsigned-size(32), _any :: binary>>) do
    {:ok, error_code(ec)}
  end
  defp decode_command("protocol.broadcast_transaction",
    <<ec :: little-integer-unsigned-size(32), _any :: binary>>) do
    {:ok, error_code(ec)}
  end
  defp decode_command("protocol.total_connections",
    <<@success :: little-integer-unsigned-size(32), connections :: little-integer-unsigned-size(32)>>) do
   {:ok, connections}
  end
  defp decode_command(_command, <<ec :: little-integer-unsigned-size(32),
                                 _rest :: binary>>) when ec != 0 do
    {:error, error_code(ec)}
  end
  defp decode_command(_any, _reply) do
    {:error, :unknown_reply}
  end

  @ephemkey_compressed 02 # assuming this is always compressed

  defp decode_stealth(<<>>, acc), do: {:ok, Enum.reverse(acc)}
  defp decode_stealth(<<ephemkey :: binary-size(32),
                        address :: binary-size(20),
                        tx_hash :: binary-size(32),
                        rest :: binary>>, acc) do

    row = %{ephemkey: <<@ephemkey_compressed, ephemkey :: binary>>,
            address: reverse_hash(address),
            tx_hash: reverse_hash(tx_hash)}
    decode_stealth(rest, [row|acc])
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
    row = %{output_hash: reverse_hash(output_hash),
            output_index: output_index,
            output_height: output_height,
            value: value,
            spend_hash: reverse_hash(spend_hash),
            spend_index: spend_index,
            spend_height: spend_height}
    decode_history1(rest, [row|acc])
  end

  defp decode_history2(<<>>, acc), do: {:ok, Enum.reverse(acc)}
  defp decode_history2(<<type :: binary-bytes-size(1),
                         hash :: binary-size(32),
                         index :: little-unsigned-integer-size(32),
                         height :: little-unsigned-integer-size(32),
                         value :: little-unsigned-integer-size(64),
                         rest :: binary>>, acc) do
    row = %{type: history_row_type(type),
            hash: reverse_hash(hash),
            index: index,
            height: height,
            value: value}
    decode_history2(rest, [row|acc])
  end


  defp history_row_type(<<0>>), do: :output
  defp history_row_type(<<1>>), do: :spend

  defp send_payload(request_id, command, payload,
    %Client{socket: socket, timeout: timeout} = state) do
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
    case :czmq.zframe_recv_all(socket) do
      {:ok, reply} ->
        handle_reply(reply, state)
      :error ->
        retry_receive_payload(state)
    end
  end

  defp handle_reply([command, <<request_id :: integer-little-unsigned-size(32)>>, reply],
                    %Client{requests: requests} = state) do
    case Map.fetch(requests, request_id) do
      {:ok, owner} when is_pid(owner) ->
        decode_command(command, reply) |> send_reply(command, request_id, owner)
        {:ok, requests} = clear_request(request_id, requests)
        {:ok, %Client{state | requests: requests}}
      :error ->
        {:error, :not_found}
    end
  end

  defp add_request(request_id, owner, %Client{requests: requests} = state) do
    {:ok, %Client{state | requests: Map.put(requests, request_id, owner)}}
  end

  defp clear_request(request_id, requests) do
    {:ok,  Map.delete(requests, request_id)}
  end

  defp retry_receive_payload(%Client{requests: []} = state) do
    {:ok, state}
  end
  defp retry_receive_payload(state) do
    :erlang.send_after(@hz, self, :receive_payload)
    {:ok, state}
  end

  defp schedule_timeout(request_id, timeout) do
    :erlang.send_after(timeout, self, {:timeout, request_id})
  end

  defp send_reply({:ok, decoded}, command, request_id, owner) do
    send(owner, {:libbitcoin_client, command, request_id, decoded})
  end

  defp send_reply({:error, reason}, command, request_id, owner) do
    send(owner, {:libbitcoin_client_error, command, request_id, reason})
  end

  defp new_request_id, do: :crypto.rand_uniform(0, 0xFFFFFFFE)

  defp encode_int(int), do: <<int :: little-integer-unsigned-size(32)>>

  defp reverse_hash(hash) do
    reverse_hash(hash, <<>>)
  end

  defp reverse_hash(<<>>, acc), do: acc
  defp reverse_hash(<<h :: binary-size(1), rest :: binary>>, acc) do
    reverse_hash(rest, <<h :: binary, acc :: binary>>)
  end

  def decode_base58check(address) do
    <<version::binary-size(1), pkh::binary-size(20), checksum::binary-size(4)>> =
      :base58.base58_to_binary(to_char_list(address))
    case  :crypto.hash(:sha256, :crypto.hash(:sha256, version <> pkh)) do
      <<^checksum :: binary-size(4), _ :: binary>> -> {version, pkh}
      _ -> {:error, :invalid_checksum}
    end
  end

  def transform_block_transactions_hashes(<<"">>, txids), do: Enum.reverse(txids)
  def transform_block_transactions_hashes(<<txid :: binary-size(32), rest :: binary>>, txids) do
    transform_block_transactions_hashes(rest, [reverse_hash(txid)|txids])
  end

  @stealth_block_size 8
  def encode_stealth(prefix), do: encode_stealth(prefix, [])

  def encode_stealth(<<>>, blocks) do
    Enum.reverse(blocks) |> IO.iodata_to_binary
  end
  def encode_stealth(<<block :: binary-size(@stealth_block_size), tail :: binary>>, blocks) do
    value = String.to_integer(block, 2) |> :binary.encode_unsigned
    encode_stealth(tail, [value|blocks])
  end
  def encode_stealth(<<block :: binary>>, blocks) do
    str = String.ljust(block, @stealth_block_size, ?0)
    encode_stealth(str, blocks)
  end
end
