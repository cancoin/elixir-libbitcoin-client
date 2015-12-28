{:ok, bs} = Libbitcoin.Client.start_link("tcp://192.168.33.11:9091")
Process.register(bs, :bs)
ExUnit.start()
