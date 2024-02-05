from time import sleep
from btcrelay.apis.bitcoinrpc import regtest


def main():
    if not len(regtest('listwallets')):
        regtest('createwallet', 'test')

    addrs = regtest('listreceivedbyaddress', 0, True)
    if not len(addrs):
        regtest('getnewaddress', 'testing', 'legacy')
        # XXX: this will return a huge list of transactions!
        addrs = regtest('listreceivedbyaddress', 0, True)

    addr = addrs[0]['address']
    del addrs

    if regtest('getbalances') == 0:
        regtest('generatetoaddress', 101, addr)

    while True:
        #print('Tick', addr, regtest('getbalances'))
        regtest('generatetoaddress', 1, addr)
        sleep(5)

main()
