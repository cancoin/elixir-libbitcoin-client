Libitcoin Client
================

---
Libbitcoin Server client for Elixir.
---


Description
-----------

Clients connect to Libbitcoin Server via a CZMQ port process.
The client provides an asynchronous query interface along with transaction,
block, and heartbeat notifications.

A user process communicates with the client process by calling functions in the
`Libbitcoin.Client` module. All functions proform their respective
operations asyncronusly. When a command is executed
it must include a reference to the owner process, which is by default is the current
process. The Client process will send Erlang messages to
the specified owner when it has recieved a response from the server.

Getting Started
---------------

To use client you need to install it as a dependancy.

```elixir
{:libbitcoin_client, ">= 0.1.0"}
```


Query Interface Usage
---------------------

The `Libbitcoin.Client.start_link/{1,2}` function must be used to start
a client.

Opening a Client connection with default options

```elixir
{:ok, client} = Libbitcoin.Client.start_link("tcp://bs1.cancoin.co")
```

Opening a client with a custom timeout

```elixir
{:ok, client} = Libbitcoin.Client.start_link("tcp://bs1.cancoin.co", %{timeout: 100})

```

Two types of messages are sent to the process owner after recieving them
from libbitcoin-server, success messages and error messages.

Success:

```elixir
{:libbitcoin_client, command-name, reference, response}
```

Error:

```elixir
{:libbitcoin_client_error, command-name, reference, error-atom}
```


Examples
--------

Getting the last height of the blockchain


```elixir
{:ok, ref} = Libbitcoin.Client.last_height(client)
receive do
  {:libbitcoin_client, "blockchain.fetch_block_height", ^ref, height} ->
     IO.puts "Last block height: #{height}"
  {:libbitcoin_client_error, "blockchain.fetch_block_height", ^ref, error} ->
     IO.puts "Error getting last block height: #{error}"
end
```


Subscription Interface Usage
----------------------------


The `Libbitcoin.Client.Sub` module provides a seperate client that
subscribes to libbitcoin-server's event channels and forwards the messages to the controlling Erlang process
in an "active-once" pattern simmilar to gen_tcp sockets. After every
message sent the controlling process must acknowledge the message by
calling `Libbitcoin.Client.Sub.ack_message/1` before any more messages
will be sent. Messages are buffered into a queue in the client process before they are
dropped.


Examples
--------

```elixir
alias Libbitcoin.Client.Sub
{:ok, client} = Sub.tranasction("tcp://bs1.cancoin.co:9091")
:ok = Sub.controlling_process(client)
receive do
  {:libbitcoin_client, :transaction, transaction} ->
    IO.puts "New transaction: #{transaction}"
    Sub.ack_message(client)
end
````





