import { Eip1193Provider } from "./1193";

/// https://eips.ethereum.org/EIPS/eip-6963
export interface EIP6963ProviderInfo {
    uuid: string;
    name: string;
    icon: string;
    rdns: string;
}


/// https://eips.ethereum.org/EIPS/eip-6963
export interface EIP6963ProviderDetail {
    info: EIP6963ProviderInfo;
    provider: Eip1193Provider;
}


/// https://eips.ethereum.org/EIPS/eip-6963
export interface EIP6963AnnounceProviderEvent extends CustomEvent {
    type: "eip6963:announceProvider";
    detail: EIP6963ProviderDetail;
}
