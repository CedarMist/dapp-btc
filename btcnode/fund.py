from math import floor
from btcrelay.apis.bitcoinrpc import regtest


def main():
    bal = regtest('getbalance')
    print('Balance', bal, )
    try:
        addr = input('Address: ').strip()
    except KeyboardInterrupt:
        return
    if not len(addr):
        return
    print('Addr:', addr)
    bal = int(floor(bal))
    x = min(bal, 5)
    try:
        amount = input(f'Amount [{x}]: ').strip()
    except KeyboardInterrupt:
        return
    if not len(amount):
        amount = x
    amount = int(amount)
    print('Amount:', amount)
    print('tx', regtest('sendtoaddress', addr, amount))

main()
