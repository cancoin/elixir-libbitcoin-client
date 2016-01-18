{:ok, bs} = Libbitcoin.Client.start_link("tcp://bs1.cancoin.co:9091")
Process.register(bs, :bs)
ExUnit.start()
