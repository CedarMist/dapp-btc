import { Exome } from "exome";

import { EIP6963AnnounceProviderEvent, EIP6963ProviderDetail, EIP6963ProviderInfo } from "./eip/6963.js";
import { Eip1193Provider, ProviderInfo, ProviderMessage } from './eip/1193.js'

import ethereumSvg from './ethereum-eth-logo.svg?raw';

const NETWORK_NAMES: {[key: number]: string} = {
    1: 'Ethereum (Mainnet)',
    0x5afe: 'Sapphire (Mainnet)',
    0x5aff: 'Sapphire (Testnet)',
    0x5afd: 'Sapphire (Localnet)',
} as const;

export class ProviderManagerStore extends Exome
{
    private _connected : boolean;
    private _chainId? : number;
    private _accounts? : string[];
    private _info: EIP6963ProviderInfo;
    private _provider: Eip1193Provider;

    constructor (in_detail: EIP6963ProviderDetail)
    {
        super();

        this._connected = false;

        this._info = in_detail.info;

        const provider = this._provider = in_detail.provider;

        provider.on('connect', this._onConnect);
        provider.on('disconnect', this._onDisconnect);
        provider.on('message', this._onMessage);
        provider.on('chainChanged', this._onChainChanged);
        provider.on('accountsChanged', this._onAccountsChanged);

        this._triggerAccountsUpdate();
        this._triggerChainIdUpdate();
    }

    public get info () {
        return this._info;
    }

    public get accounts () {
        return this._accounts;
    }

    public get provider () {
        return this._provider;
    }

    public get chainId () {
        return this._chainId;
    }

    public get connected () {
        return this._connected;
    }

    public get chainName () {
        if( this._chainId ) {
            if( this._chainId in NETWORK_NAMES ) {
                return NETWORK_NAMES[this._chainId];
            }
            return `Unknown (${this._chainId})`;
        }
        return undefined;
    }

    async _triggerAccountsUpdate() {
        this._setAccounts(await this._provider.request({method:'eth_accounts'}));
    }

    async _triggerChainIdUpdate() {
        this._setChainId(await this._provider.request({method:'eth_chainId'}));
    }

    _setChainId(chainId?: string) {
        if( chainId ) {
            this._chainId = parseInt(chainId);
            console.log('ChainChanged', this._info, this._chainId);
        }
        else {
            this._chainId = undefined;
        }
    }

    public dispose() {
        this._provider.removeListener('connect', this._onConnect);
        this._provider.removeListener('disconnect', this._onDisconnect);
        this._provider.removeListener('message', this._onMessage);
        this._provider.removeListener('chainChanged', this._onChainChanged);
        this._provider.removeListener('accountsChanged', this._onAccountsChanged);
    }

    private _setAccounts (accounts:string[]) {
        this._accounts = accounts;
        this._connected = accounts.length > 0;
    }

    public async connect() {
        try {
            this._setAccounts(await this._provider.request({method:'eth_requestAccounts'}));
        }
        catch(error:any) {
            if( error.code == 4001 ) {
                return false;
            }
            throw error;
        }
        return true;
    }

    private async _onConnect(info: ProviderInfo) {
        this._setChainId(info.chainId);
        this._setAccounts(await this._provider.request({method: 'eth_accounts'}));
    }

    private async _onDisconnect(/*error: ProviderRpcError*/) {
        this._connected = false;
        this._setChainId();
        this._accounts = undefined;
    }

    private async _onMessage(message: ProviderMessage) {
        console.log('Message', this._info, message);
    }

    private async _onChainChanged(chainId: string) {
        this._setChainId(chainId);
    }

    private async _onAccountsChanged(accounts: string[]) {
        this._setAccounts(accounts);
    }
}


class ProvidersStore extends Exome
{
    public isEIP6963:boolean = false;
    public isEIP1193:boolean = false;
    public providerCount:number = 0;
    public providers: Map<string,ProviderManagerStore> = new Map();

    constructor ()
    {
        super();

        window.addEventListener('DOMContentLoaded', this._onDOMContentLoaded.bind(this));
    }

    public async _onAnnounceProvider( event: EIP6963AnnounceProviderEvent )
    {
        const { info } = event.detail;

        if( ! (info.uuid in this.providers) )
        {
            // The default provider is removed when any EIP6963 providers are found
            if( this.providers.has('window.ethereum') )
            {
                const p = this.providers.get('window.ethereum')!;

                p.dispose();

                this.isEIP6963 = true;

                this.isEIP1193 = false;

                this.providers.delete('window.ethereum')
            }

            this.providers.set(info.uuid, new ProviderManagerStore(event.detail));

            this.providerCount = this.providers.size;
        }
    }

    public _onDOMContentLoaded()
    {
        // If there isn't an EIP-6963 compatible provider, but there's EIP-1193
        // then add it (which will be removed if we discover EIP-6963)
        if( window.ethereum )
        {
            this.isEIP1193 = true;

            this.providers.set('window.ethereum', new ProviderManagerStore({
                info: {
                    uuid: 'window.ethereum',
                    name: 'window.ethereum (EIP-1193)',
                    icon: 'data:image/svg+xml,' + encodeURIComponent(ethereumSvg),
                    rdns: 'window.ethereum'
                },
                provider: window.ethereum as any
            }));
        }

        window.addEventListener("eip6963:announceProvider",
            ((_event:any) => {
                this._onAnnounceProvider(_event);
            }).bind(this)
        );

        window.dispatchEvent(new Event("eip6963:requestProvider"));
    }
}

export const providerStore = new ProvidersStore();
