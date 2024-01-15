import { readFile, writeFile } from 'node:fs/promises';

async function stuff(mode, btc_net, sapphire_net) {
    const x = await readFile('../btcrelay/deployments/btc-' + btc_net + '_sapphire-' + sapphire_net + '.json');
    const y = JSON.parse(x);

    let content = [];
    for( let [k,v] of Object.entries(y) ) {
        content.push('VITE_' + k + '_ADDR=' + v['expected_address']);
    }
    content.push('VITE_BTC_NET='+btc_net);
    content.push('VITE_SAPPHIRE_NET='+sapphire_net);

    writeFile('.env.' + mode, content.join('\n') + '\n');
}

await stuff('local', 'testnet', 'localnet');
//await stuff('staging', 'testnet', 'testnet');
//await stuff('production', 'mainnet', 'mainnet');
