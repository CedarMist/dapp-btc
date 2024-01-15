/// Ethers JS is retarded, their EIP-1193 provider doesn't actually implement EIP-1193
// import { Eip1193Provider } from "ethers";

export interface ProviderMessage {
    readonly type: string;
    readonly data: unknown;
}

export interface ProviderInfo {
	chainId: string;
}

export interface ProviderRpcError extends Error {
	readonly code: number;
	readonly data?: unknown;
}

interface MetaMask1193Extensions {
	isUnlocked(): Promise<boolean>;
}

export interface Eip1193Provider {
	// See: https://eips.ethereum.org/EIPS/eip-1474
	request(request: { method: 'eth_chainId' }): Promise<`0x${string}`>;
	request(request: { method: 'eth_coinbase' }): Promise<`0x${string}`>;
	request(request: { method: 'eth_gasPrice' }): Promise<`0x${string}`>;
	request(request: { method: 'eth_blockNumber' }): Promise<`0x${string}`>;
	request(request: { method: 'eth_accounts' }): Promise<`0x${string}`[]>;
	request(request: { method: 'eth_requestAccounts' }): Promise<`0x${string}`[]>;
    request(request: { method: string, params?: Array<any> | Record<string, any> }): Promise<any>;

    on(event: 'connect', listener: (info: ProviderInfo) => void): Eip1193Provider;
	on(event: 'disconnect', listener: (error: ProviderRpcError) => void): Eip1193Provider;
	on(event: 'message', listener: (message: ProviderMessage) => void): Eip1193Provider;
	on(event: 'chainChanged', listener: (chainId: string) => void): Eip1193Provider;
	on(event: 'accountsChanged', listener: (accounts: string[]) => void): Eip1193Provider;

	removeListener(event: 'connect', listener: (info: ProviderInfo) => void): void;
	removeListener(event: 'disconnect', listener: (error: ProviderRpcError) => void): void;
	removeListener(event: 'message', listener: (message: ProviderMessage) => void): void;
	removeListener(event: 'chainChanged', listener: (chainId: string) => void): void;
	removeListener(event: 'accountsChanged', listener: (accounts: string[]) => void): void;

    isMetaMask?: boolean;

	_metamask?: MetaMask1193Extensions;
}
