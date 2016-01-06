{:ok, bs} = Libbitcoin.Client.start_link("tcp://198.27.69.77:9091")
Process.register(bs, :bs)
ExUnit.start()
