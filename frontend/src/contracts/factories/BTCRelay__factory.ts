/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Interface, type ContractRunner } from "ethers";
import type { BTCRelay, BTCRelayInterface } from "../BTCRelay";

const _abi = [
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "in_blockHash",
        type: "bytes32",
      },
      {
        internalType: "uint256",
        name: "in_blockHeight",
        type: "uint256",
      },
      {
        internalType: "uint32",
        name: "in_time",
        type: "uint32",
      },
      {
        internalType: "uint256",
        name: "in_bits",
        type: "uint256",
      },
      {
        internalType: "bool",
        name: "in_isTestnet",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "in_height",
        type: "uint256",
      },
    ],
    name: "getBlockHash",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "in_height",
        type: "uint256",
      },
    ],
    name: "getBlockHashReversed",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getBtcRelay",
    outputs: [
      {
        internalType: "contract IBtcMirror",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getChainParams",
    outputs: [
      {
        components: [
          {
            internalType: "string",
            name: "name",
            type: "string",
          },
          {
            internalType: "uint32",
            name: "magic",
            type: "uint32",
          },
          {
            internalType: "uint8",
            name: "pubkeyAddrPrefix",
            type: "uint8",
          },
          {
            internalType: "uint8",
            name: "scriptAddrPrefix",
            type: "uint8",
          },
        ],
        internalType: "struct IBtcMirror.ChainParams",
        name: "",
        type: "tuple",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getLatestBlockHeight",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getLatestBlockTime",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getMinConfirmations",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [],
    name: "isTestnet",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "startHeight",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "in_height",
        type: "uint256",
      },
      {
        components: [
          {
            internalType: "bytes32",
            name: "previousblockhash",
            type: "bytes32",
          },
          {
            internalType: "bytes32",
            name: "merkleroot",
            type: "bytes32",
          },
          {
            internalType: "uint32",
            name: "version",
            type: "uint32",
          },
          {
            internalType: "uint32",
            name: "time",
            type: "uint32",
          },
          {
            internalType: "uint32",
            name: "bits",
            type: "uint32",
          },
          {
            internalType: "uint32",
            name: "nonce",
            type: "uint32",
          },
        ],
        internalType: "struct AbstractRelay.BlockHeader[]",
        name: "in_headers",
        type: "tuple[]",
      },
    ],
    name: "submit",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes4",
        name: "interfaceId",
        type: "bytes4",
      },
    ],
    name: "supportsInterface",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
] as const;

export class BTCRelay__factory {
  static readonly abi = _abi;
  static createInterface(): BTCRelayInterface {
    return new Interface(_abi) as BTCRelayInterface;
  }
  static connect(address: string, runner?: ContractRunner | null): BTCRelay {
    return new Contract(address, _abi, runner) as unknown as BTCRelay;
  }
}