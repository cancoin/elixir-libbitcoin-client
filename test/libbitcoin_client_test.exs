defmodule BitcoinClientTest do
  alias Libbitcoin.Client, as: C
  use ExUnit.Case

  @timeout 2000

  test "blockchain.fetch_last_height" do
    assert {:ok, ref} = C.last_height(:bs)
    assert_receive {:libbitcoin_client, "blockchain.fetch_last_height", ^ref, height} when is_integer(height), @timeout
  end

  test "blockchain.fetch_block_header" do
    {:ok, hash} = Base.decode16("00000000D1145790A8694403D4063F323D499E655C83426834D4CE2F8DD4A2EE")
    assert {:ok, ref} = C.block_height(:bs, hash)
    assert_receive {:libbitcoin_client, "blockchain.fetch_block_height", ^ref, 170}, @timeout
  end

  test "blockchain.fetch_block_header not found" do
    {:ok, hash} = Base.decode16("00000000AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    assert {:ok, ref} = C.block_height(:bs, hash)
    assert_receive {:libbitcoin_client_error, "blockchain.fetch_block_height", ^ref, :not_found}, @timeout
  end

  test "blockchain.block_header" do
    assert {:ok, ref} = C.block_header(:bs, 170)
    assert_receive {:libbitcoin_client, "blockchain.fetch_block_header", ^ref, header} when is_binary(header), @timeout
  end

  test "blockchain.block_transaction_hashes" do
    {:ok, hash} = Base.decode16("00000000D1145790A8694403D4063F323D499E655C83426834D4CE2F8DD4A2EE")
    assert {:ok, ref} = C.block_transaction_hashes(:bs, hash)
    hashes = Enum.map ["B1FEA52486CE0C62BB442B530A3F0132B826C74E473D1F2C220BFA78111C5082",
                       "F4184FC596403B9D638783CF57ADFE4C75C605F6356FBC91338530E9831E9E16"], &Base.decode16!(&1)
    assert_receive {:libbitcoin_client, "blockchain.fetch_block_transaction_hashes", ^ref, ^hashes}, @timeout
  end

  test "blockchain.fetch_transaction" do
    {:ok, hash} = Base.decode16("F4184FC596403B9D638783CF57ADFE4C75C605F6356FBC91338530E9831E9E16")
    assert {:ok, ref} = C.blockchain_transaction(:bs, hash)
    assert_receive {:libbitcoin_client, "blockchain.fetch_transaction", ^ref, tx} when is_binary(tx), @timeout
  end

  test "blockchain.fetch_transaction not found" do
    {:ok, hash} = Base.decode16("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    assert {:ok, ref} = C.blockchain_transaction(:bs, hash)
    assert_receive {:libbitcoin_client_error, "blockchain.fetch_transaction", ^ref, :not_found}, @timeout
  end

  test "blockchain.fetch_spend" do
    {:ok, hash} = Base.decode16("F4184FC596403B9D638783CF57ADFE4C75C605F6356FBC91338530E9831E9E16")
    assert {:ok, ref} = C.spend(:bs, hash, 1)
    assert_receive {:libbitcoin_client, "blockchain.fetch_spend", ^ref, {txid, index}} when is_binary(txid) and is_integer(index), @timeout
  end

  test "transaction_pool.fetch_transaction" do
    {:ok, hash} = Base.decode16("F4184FC596403B9D638783CF57ADFE4C75C605F6356FBC91338530E9831E9E16")
    assert {:ok, ref} = C.blockchain_transaction(:bs, hash)
    assert_receive {:libbitcoin_client, "blockchain.fetch_transaction", ^ref, tx} when is_binary(tx), @timeout
  end

  test "transaction_pool.validate" do
    {:ok, tx} = Base.decode16("0100000001ACA7F3B45654C230E0886A57FB988C3044EF5E8F7F39726D305C61D5E818903C00000000FD5D010048304502200187AF928E9D155C4B1AC9C1C9118153239ABA76774F775D7C1F9C3E106FF33C0221008822B0F658EDEC22274D0B6AE9DE10EBF2DA06B1BBDAABA4E50EB078F39E3D78014730440220795F0F4F5941A77AE032ECB9E33753788D7EB5CB0C78D805575D6B00A1D9BFED02203E1F4AD9332D1416AE01E27038E945BC9DB59C732728A383A6F1ED2FB99DA7A4014CC952410491BBA2510912A5BD37DA1FB5B1673010E43D2C6D812C514E91BFA9F2EB129E1C183329DB55BD868E209AAC2FBC02CB33D98FE74BF23F0C235D6126B1D8334F864104865C40293A680CB9C020E7B1E106D8C1916D3CEF99AA431A56D253E69256DAC09EF122B1A986818A7CB624532F062C1D1F8722084861C5C3291CCFFEF4EC687441048D2455D2403E08708FC1F556002F1B6CD83F992D085097F9974AB08A28838F07896FBAB08F39495E15FA6FAD6EDBFB1E754E35FA1C7844C41F322A1863D4621353AEFFFFFFFF0140420F00000000001976A914AE56B4DB13554D321C402DB3961187AED1BBED5B88AC00000000")
    assert {:ok, ref} = C.validate(:bs, tx)
    assert_receive {:libbitcoin_client, "transaction_pool.validate", ^ref, :duplicate} when is_binary(tx), @timeout
  end

  test "address.fetch_history" do
    assert {:ok, ref} = C.address_history(:bs, "12cbQLTFMXRnSzktFkuoG3eHoMeFtpTu3S", 0)
    assert_receive {:libbitcoin_client, "address.fetch_history", ^ref, [row|_]} when is_map(row), @timeout
  end

  test "address.fetch_history2" do
    assert {:ok, ref} = C.address_history2(:bs, "12cbQLTFMXRnSzktFkuoG3eHoMeFtpTu3S", 0)
    assert_receive {:libbitcoin_client, "address.fetch_history2", ^ref, [row|_]} when is_map(row), @timeout
  end

  test "blockchain.fetch_history" do
    assert {:ok, ref} = C.blockchain_history(:bs, "12cbQLTFMXRnSzktFkuoG3eHoMeFtpTu3S", 0)
    assert_receive {:libbitcoin_client, "blockchain.fetch_history", ^ref, [row|_]} when is_map(row), @timeout
  end

  test "blockchain.fetch_stealth" do
    ephemkey = Base.decode16!( "0269642b87b0898e1f079be72d194b86aca0b54eff41844ac28ec70c564db4991a", case: :lower)
    address = Base.decode16!("d4b516796c8be0b529d0aa6317b9087598f2d709", case: :lower)
    tx_hash = Base.decode16!( "f12551534a2a8ff97ed80ee4742beae2569b663ba319070742d0f4bf88b654c3", case: :lower)

    assert {:ok, ref} = C.stealth(:bs, "11111111111111111", 0)
    assert_receive({:libbitcoin_client, _, ^ref, [
        %{ephemkey: ^ephemkey, address: ^address, tx_hash: ^tx_hash}|_]}, @timeout)
  end

  test "protocol.total_connections" do
    assert {:ok, ref} = C.total_connections(:bs)
    assert_receive {:libbitcoin_client, _, ^ref, connections} when is_integer(connections), @timeout
    assert connections > 0
  end

  test "transaction_pool.broadcast_tranaction" do
    {:ok, tx} = Base.decode16("0100000001ACA7F3B45654C230E0886A57FB988C3044EF5E8F7F39726D305C61D5E818903C00000000FD5D010048304502200187AF928E9D155C4B1AC9C1C9118153239ABA76774F775D7C1F9C3E106FF33C0221008822B0F658EDEC22274D0B6AE9DE10EBF2DA06B1BBDAABA4E50EB078F39E3D78014730440220795F0F4F5941A77AE032ECB9E33753788D7EB5CB0C78D805575D6B00A1D9BFED02203E1F4AD9332D1416AE01E27038E945BC9DB59C732728A383A6F1ED2FB99DA7A4014CC952410491BBA2510912A5BD37DA1FB5B1673010E43D2C6D812C514E91BFA9F2EB129E1C183329DB55BD868E209AAC2FBC02CB33D98FE74BF23F0C235D6126B1D8334F864104865C40293A680CB9C020E7B1E106D8C1916D3CEF99AA431A56D253E69256DAC09EF122B1A986818A7CB624532F062C1D1F8722084861C5C3291CCFFEF4EC687441048D2455D2403E08708FC1F556002F1B6CD83F992D085097F9974AB08A28838F07896FBAB08F39495E15FA6FAD6EDBFB1E754E35FA1C7844C41F322A1863D4621353AEFFFFFFFF0140420F00000000001976A914AE56B4DB13554D321C402DB3961187AED1BBED5B88AC00000000")
    assert {:ok, ref} = C.validate(:bs, tx)
    assert_receive {:libbitcoin_client, "transaction_pool.validate", ^ref, :duplicate} when is_binary(tx), @timeout
  end

  test "encode_stealth" do
    assert "ba80" = C.encode_stealth("101110101") |> Base.encode16(case: :lower)
    assert "a680" = C.encode_stealth("101001101") |> Base.encode16(case: :lower)
    assert "bae0" = C.encode_stealth("10111010111") |> Base.encode16(case: :lower)
    assert "fff8c0" = C.encode_stealth("111111111111100011") |> Base.encode16(case: :lower)
  end

  test "spend_checksum" do
    hash = Base.decode16!("ab00248cd12452c2c45be7ca91899fd8e174595b4d16e2f2e3c92dedbb1d8cea", case: :lower)
    assert C.spend_checksum(hash, 0) == 7190328776004206592
  end
end
