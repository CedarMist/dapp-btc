/// <reference types="vite/client" />

import { EIP1193Provider } from "./eip/1193.js";

interface ImportMetaEnv {
    readonly VITE_BTCRelay_ADDR: `0x${string}`
    readonly VITE_BTCDeposit_ADDR: `0x${string}`
    readonly VITE_TxVerifier_ADDR: `0x${string}`
    readonly VITE_LiquidBTC_ADDR: `0x${string}`
    readonly VITE_BTC_NET: 'localnet' | 'testnet' | 'mainnet'
    readonly VITE_SAPPHIRE_NET: 'localnet' | 'testnet' | 'mainnet'
}

interface ImportMeta {
    readonly env: ImportMetaEnv
}

declare global {
    interface Window {
        ethereum: EIP1193Provider;
    }
}
