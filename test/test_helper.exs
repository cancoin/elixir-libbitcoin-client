{:ok, bs} = Libbitcoin.Client.start_link("tcp://voyager-api.cancoin.co:9091")
Process.register(bs, :bs)
ExUnit.start()
