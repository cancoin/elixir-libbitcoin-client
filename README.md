Libitcoin Client
================

---
Libbitcoin Server client for Elixir.
---


Description
-----------

The client connects to Libbitcoin Server via a CZMQ port process and provides an asynchronous query interface along with transaction, block, and heartbeat notifications.

The controlling process communicates with the client by calling functions in the
`Libbitcoin.Client` module. All functions proform their respective
operations asyncronusly. When a command is executed it must include a reference
to the owner process, which is by default is the current
process. The client process will send Erlang messages to
the specified owner when it has recieved a response from the server.

Getting Started
---------------

To use client you need to install it as a dependancy.

```elixir
{:libbitcoin_client, github: "cancoin/elixir-libbitcoin-client"}
```

Usage
---------------------

The `Libbitcoin.Client.start_link/{1,2}` function must be used to start
a client.

Opening a Client connection with default options

```elixir
{:ok, client} = Libbitcoin.Client.start_link("tcp://bs1.cancoin.co:9091")
```

Opening a client with a custom timeout

```elixir
{:ok, client} = Libbitcoin.Client.start_link("tcp://bs1.cancoin.co:9091", %{timeout: 100})

```

Two types of messages are sent to the process owner in response to queries.

Success:

```elixir
{:libbitcoin_client, command-name, reference, response}
```

Error:

```elixir
{:libbitcoin_client_error, command-name, reference, error-atom}
```

#### Examples

Getting the last height of the blockchain

```elixir
{:ok, ref} = Libbitcoin.Client.last_height(client)
receive do
  {:libbitcoin_client, "blockchain.fetch_last_height", ^ref, height} ->
     IO.puts "Last block height: #{height}"
  {:libbitcoin_client_error, "blockchain.fetch_last_height", ^ref, error} ->
     IO.puts "Error getting last block height: #{error}"
end
```


Subscriptions
-------------

The `Libbitcoin.Client.Sub` module provides a seperate client that
subscribes to libbitcoin-server's event channels and forwards the messages to the controlling Erlang process
in an "active-once" pattern simmilar to gen_tcp sockets. After every
message received the controlling process must acknowledge the message by
calling `Libbitcoin.Client.Sub.ack_message/1` before any more messages
will be sent. Messages are buffered into a queue in the client process before they are
dropped when a (soon to be) configurable maximum length is reached.

#### Examples

#### Subscribe to transactions

```elixir
alias Libbitcoin.Client.Sub
{:ok, client} = Sub.transaction("tcp://voyager-api.cancoin.co:9094")
:ok = Sub.controlling_process(client)
receive do
  {:libbitcoin_client, :transaction, transaction} ->
    IO.puts "New transaction: #{Base.encode16(transaction)}"
    Sub.ack_message(client)
end
```

#### Subscribe to Blocks

```elixir
alias Libbitcoin.Client.Sub
{:ok, client} = Sub.block("tcp://voyager-api.cancoin.co:9093")
:ok = Sub.controlling_process(client)
receive do
  {:libbitcoin_client, :block, {height, header, txids}} ->
    IO.puts "New block at #{height}"
    Sub.ack_message(client)
end
````

As a GenServer

```elixir
defmodule TxSub do
  alias Libbitcoin.Client.Sub
  use GenServer

  def init([uri]) do
    {:ok, client} = Sub.transaction(uri)
    :ok = Sub.controlling_process(client)
    {:ok, %{client: client}}
  end

  def handle_info({:libbitcoin_client, :transaction, transaction}, %{client: client} = state) do
    IO.inspect "New transaction: #{Base.encode16(transaction)}"
    Sub.ack_message(client)
    {:noreply, state}
  end
end

GenServer.start_link(TxSub, ["tcp://voyager-api.cancoin.co:9094"])
```





