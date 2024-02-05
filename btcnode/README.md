# bitcoin regtest node

Run a local regtest node, fund acounts, fast mining (5 seconds).

    make run &      # Run regtest node
    make tick       # Run block auto-miner
    make qt         # Start QT wallet, autoconnected to node

The data dirs are cleaned every time `run` or `qt` are started.

You can then fund accounts from the miner using:

    make fund

Which will ask for the address, and amount, then print the transaction id
