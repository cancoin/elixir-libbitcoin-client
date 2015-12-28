defmodule BitcoinClientTest do
  alias Libbitcoin.Client, as: C
  use ExUnit.Case

  test "blockchain.fetch_last_height" do
    assert {:ok, ref} = C.last_height(:bs)
    assert_receive {:libbitcoin_client, "blockchain.fetch_last_height", ^ref, height} when is_integer(height)
  end

  test "blockchain.fetch_block_header" do
    {:ok, hash} = Base.decode16("00000000D1145790A8694403D4063F323D499E655C83426834D4CE2F8DD4A2EE")
    assert {:ok, ref} = C.block_height(:bs, hash)
    assert_receive {:libbitcoin_client, "blockchain.fetch_block_height", ^ref, 170}
  end

  test "blockchain.fetch_block_header not found" do
    {:ok, hash} = Base.decode16("00000000AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    assert {:ok, ref} = C.block_height(:bs, hash)
    assert_receive {:libbitcoin_client_error, "blockchain.fetch_block_height", ^ref, :not_found}
  end

  test "blockchain.block_header" do
    assert {:ok, ref} = C.block_header(:bs, 170)
    assert_receive {:libbitcoin_client, "blockchain.fetch_block_header", ^ref, header} when is_binary(header)
  end

  test "blockchain.block_transaction_hashes" do
    {:ok, hash} = Base.decode16("00000000D1145790A8694403D4063F323D499E655C83426834D4CE2F8DD4A2EE")
    assert {:ok, ref} = C.block_transaction_hashes(:bs, hash)
    hashes = Enum.map ["B1FEA52486CE0C62BB442B530A3F0132B826C74E473D1F2C220BFA78111C5082",
                       "F4184FC596403B9D638783CF57ADFE4C75C605F6356FBC91338530E9831E9E16"], &Base.decode16!(&1)
    assert_receive {:libbitcoin_client, "blockchain.fetch_block_transaction_hashes", ref, ^hashes}
  end

  test "blockchain.fetch_transaction" do
    {:ok, hash} = Base.decode16("F4184FC596403B9D638783CF57ADFE4C75C605F6356FBC91338530E9831E9E16")
    assert {:ok, ref} = C.blockchain_transaction(:bs, hash)
    assert_receive {:libbitcoin_client, "blockchain.fetch_transaction", ^ref, tx} when is_binary(tx)
  end

  test "blockchain.fetch_transaction not found" do
    {:ok, hash} = Base.decode16("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    assert {:ok, ref} = C.blockchain_transaction(:bs, hash)
    assert_receive {:libbitcoin_client_error, "blockchain.fetch_transaction", ^ref, :not_found}
  end

  test "transaction_pool.fetch_transaction" do
    {:ok, hash} = Base.decode16("F4184FC596403B9D638783CF57ADFE4C75C605F6356FBC91338530E9831E9E16")
    assert {:ok, ref} = C.blockchain_transaction(:bs, hash)
    assert_receive {:libbitcoin_client, "blockchain.fetch_transaction", ^ref, tx} when is_binary(tx)
  end

  test "blockchain.fetch_spend" do
    {:ok, hash} = Base.decode16("F4184FC596403B9D638783CF57ADFE4C75C605F6356FBC91338530E9831E9E16")
    assert {:ok, ref} = C.spend(:bs, hash, 1)
    assert_receive {:libbitcoin_client, "blockchain.fetch_spend", ^ref, {txid, index}} when is_binary(txid) and is_integer(index)
  end

  test "address.fetch_history" do
    assert {:ok, ref} = C.address_history(:bs, "12cbQLTFMXRnSzktFkuoG3eHoMeFtpTu3S", 0)
    assert_receive {:libbitcoin_client, "address.fetch_history", ^ref, [row|_]} when is_map(row)
  end

  test "address.fetch_history2" do
    assert {:ok, ref} = C.address_history2(:bs, "12cbQLTFMXRnSzktFkuoG3eHoMeFtpTu3S", 0)
    assert_receive {:libbitcoin_client, "address.fetch_history2", ^ref, [row|_]} when is_map(row)
  end

  test "blokchain.fetch_history" do
    assert {:ok, ref} = C.blockchain_history(:bs, "12cbQLTFMXRnSzktFkuoG3eHoMeFtpTu3S", 0)
    assert_receive {:libbitcoin_client, "blockchain.fetch_history", ^ref, [row|_]} when is_map(row)
  end
end
