/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumberish,
  BytesLike,
  FunctionFragment,
  Result,
  Interface,
  AddressLike,
  ContractRunner,
  ContractMethod,
  Listener,
} from "ethers";
import type {
  TypedContractEvent,
  TypedDeferredTopicFilter,
  TypedEventLog,
  TypedListener,
  TypedContractMethod,
} from "./common";

export type BtcTxProofStruct = {
  blockHeader: BytesLike;
  txId: BytesLike;
  txIndex: BigNumberish;
  txMerkleProof: BytesLike;
  rawTx: BytesLike;
};

export type BtcTxProofStructOutput = [
  blockHeader: string,
  txId: string,
  txIndex: bigint,
  txMerkleProof: string,
  rawTx: string
] & {
  blockHeader: string;
  txId: string;
  txIndex: bigint;
  txMerkleProof: string;
  rawTx: string;
};

export interface BTCDepositInterface extends Interface {
  getFunction(
    nameOrSignature:
      | "burn"
      | "create"
      | "createDerived"
      | "deposit"
      | "depositDerived"
      | "derive"
      | "getBtcRelay"
      | "getMeta"
      | "getSecret"
      | "purge"
      | "safeTransferMany"
      | "supportsInterface"
  ): FunctionFragment;

  encodeFunctionData(functionFragment: "burn", values: [BytesLike]): string;
  encodeFunctionData(functionFragment: "create", values: [AddressLike]): string;
  encodeFunctionData(
    functionFragment: "createDerived",
    values: [AddressLike, BigNumberish, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "deposit",
    values: [BigNumberish, BtcTxProofStruct, BigNumberish, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "depositDerived",
    values: [
      AddressLike,
      BigNumberish,
      BytesLike,
      BigNumberish,
      BtcTxProofStruct,
      BigNumberish,
      BytesLike
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "derive",
    values: [AddressLike, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "getBtcRelay",
    values?: undefined
  ): string;
  encodeFunctionData(functionFragment: "getMeta", values: [BytesLike]): string;
  encodeFunctionData(
    functionFragment: "getSecret",
    values: [BytesLike]
  ): string;
  encodeFunctionData(functionFragment: "purge", values: [BytesLike]): string;
  encodeFunctionData(
    functionFragment: "safeTransferMany",
    values: [AddressLike, BytesLike[]]
  ): string;
  encodeFunctionData(
    functionFragment: "supportsInterface",
    values: [BytesLike]
  ): string;

  decodeFunctionResult(functionFragment: "burn", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "create", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "createDerived",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "deposit", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "depositDerived",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "derive", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "getBtcRelay",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "getMeta", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "getSecret", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "purge", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "safeTransferMany",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "supportsInterface",
    data: BytesLike
  ): Result;
}

export interface BTCDeposit extends BaseContract {
  connect(runner?: ContractRunner | null): BTCDeposit;
  waitForDeployment(): Promise<this>;

  interface: BTCDepositInterface;

  queryFilter<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TypedEventLog<TCEvent>>>;
  queryFilter<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TypedEventLog<TCEvent>>>;

  on<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    listener: TypedListener<TCEvent>
  ): Promise<this>;
  on<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    listener: TypedListener<TCEvent>
  ): Promise<this>;

  once<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    listener: TypedListener<TCEvent>
  ): Promise<this>;
  once<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    listener: TypedListener<TCEvent>
  ): Promise<this>;

  listeners<TCEvent extends TypedContractEvent>(
    event: TCEvent
  ): Promise<Array<TypedListener<TCEvent>>>;
  listeners(eventName?: string): Promise<Array<Listener>>;
  removeAllListeners<TCEvent extends TypedContractEvent>(
    event?: TCEvent
  ): Promise<this>;

  burn: TypedContractMethod<[in_keypairId: BytesLike], [void], "nonpayable">;

  create: TypedContractMethod<
    [in_owner: AddressLike],
    [[string, string] & { out_pubkeyAddress: string; out_keypairId: string }],
    "nonpayable"
  >;

  createDerived: TypedContractMethod<
    [
      in_owner: AddressLike,
      in_derive_epoch: BigNumberish,
      in_derive_seed: BytesLike
    ],
    [[string, string] & { out_pubkeyAddress: string; out_keypairId: string }],
    "nonpayable"
  >;

  deposit: TypedContractMethod<
    [
      blockNum: BigNumberish,
      inclusionProof: BtcTxProofStruct,
      txOutIx: BigNumberish,
      keypairId: BytesLike
    ],
    [bigint],
    "nonpayable"
  >;

  depositDerived: TypedContractMethod<
    [
      in_owner: AddressLike,
      in_derive_epoch: BigNumberish,
      in_derive_seed: BytesLike,
      in_blockNum: BigNumberish,
      in_inclusionProof: BtcTxProofStruct,
      in_txOutIx: BigNumberish,
      in_keypairId: BytesLike
    ],
    [bigint],
    "nonpayable"
  >;

  derive: TypedContractMethod<
    [in_owner: AddressLike, in_derive_seed: BytesLike],
    [
      [string, string, bigint] & {
        out_pubkeyAddress: string;
        out_keypairId: string;
        out_derive_epoch: bigint;
      }
    ],
    "view"
  >;

  getBtcRelay: TypedContractMethod<[], [string], "view">;

  getMeta: TypedContractMethod<
    [in_keypairId: BytesLike],
    [[bigint, bigint] & { out_burnHeight: bigint; out_sats: bigint }],
    "view"
  >;

  getSecret: TypedContractMethod<
    [in_keypairId: BytesLike],
    [[string, string] & { out_btcAddress: string; out_secret: string }],
    "view"
  >;

  purge: TypedContractMethod<[in_keypairId: BytesLike], [void], "nonpayable">;

  safeTransferMany: TypedContractMethod<
    [in_to: AddressLike, in_keypairId_list: BytesLike[]],
    [void],
    "nonpayable"
  >;

  supportsInterface: TypedContractMethod<
    [interfaceId: BytesLike],
    [boolean],
    "view"
  >;

  getFunction<T extends ContractMethod = ContractMethod>(
    key: string | FunctionFragment
  ): T;

  getFunction(
    nameOrSignature: "burn"
  ): TypedContractMethod<[in_keypairId: BytesLike], [void], "nonpayable">;
  getFunction(
    nameOrSignature: "create"
  ): TypedContractMethod<
    [in_owner: AddressLike],
    [[string, string] & { out_pubkeyAddress: string; out_keypairId: string }],
    "nonpayable"
  >;
  getFunction(
    nameOrSignature: "createDerived"
  ): TypedContractMethod<
    [
      in_owner: AddressLike,
      in_derive_epoch: BigNumberish,
      in_derive_seed: BytesLike
    ],
    [[string, string] & { out_pubkeyAddress: string; out_keypairId: string }],
    "nonpayable"
  >;
  getFunction(
    nameOrSignature: "deposit"
  ): TypedContractMethod<
    [
      blockNum: BigNumberish,
      inclusionProof: BtcTxProofStruct,
      txOutIx: BigNumberish,
      keypairId: BytesLike
    ],
    [bigint],
    "nonpayable"
  >;
  getFunction(
    nameOrSignature: "depositDerived"
  ): TypedContractMethod<
    [
      in_owner: AddressLike,
      in_derive_epoch: BigNumberish,
      in_derive_seed: BytesLike,
      in_blockNum: BigNumberish,
      in_inclusionProof: BtcTxProofStruct,
      in_txOutIx: BigNumberish,
      in_keypairId: BytesLike
    ],
    [bigint],
    "nonpayable"
  >;
  getFunction(
    nameOrSignature: "derive"
  ): TypedContractMethod<
    [in_owner: AddressLike, in_derive_seed: BytesLike],
    [
      [string, string, bigint] & {
        out_pubkeyAddress: string;
        out_keypairId: string;
        out_derive_epoch: bigint;
      }
    ],
    "view"
  >;
  getFunction(
    nameOrSignature: "getBtcRelay"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "getMeta"
  ): TypedContractMethod<
    [in_keypairId: BytesLike],
    [[bigint, bigint] & { out_burnHeight: bigint; out_sats: bigint }],
    "view"
  >;
  getFunction(
    nameOrSignature: "getSecret"
  ): TypedContractMethod<
    [in_keypairId: BytesLike],
    [[string, string] & { out_btcAddress: string; out_secret: string }],
    "view"
  >;
  getFunction(
    nameOrSignature: "purge"
  ): TypedContractMethod<[in_keypairId: BytesLike], [void], "nonpayable">;
  getFunction(
    nameOrSignature: "safeTransferMany"
  ): TypedContractMethod<
    [in_to: AddressLike, in_keypairId_list: BytesLike[]],
    [void],
    "nonpayable"
  >;
  getFunction(
    nameOrSignature: "supportsInterface"
  ): TypedContractMethod<[interfaceId: BytesLike], [boolean], "view">;

  filters: {};
}
