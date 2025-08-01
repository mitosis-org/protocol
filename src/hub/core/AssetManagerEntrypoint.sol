// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IMessageRecipient } from '@hpl/interfaces/IMessageRecipient.sol';

import { Ownable2StepUpgradeable } from '@ozu/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu/proxy/utils/UUPSUpgradeable.sol';

import { GasRouter } from '../../external/hyperlane/GasRouter.sol';
import { IAssetManager } from '../../interfaces/hub/core/IAssetManager.sol';
import { IAssetManagerEntrypoint } from '../../interfaces/hub/core/IAssetManagerEntrypoint.sol';
import { ICrossChainRegistry } from '../../interfaces/hub/cross-chain/ICrossChainRegistry.sol';
import { Conv } from '../../lib/Conv.sol';
import { StdError } from '../../lib/StdError.sol';
import { Versioned } from '../../lib/Versioned.sol';
import '../../message/Message.sol';
import { AssetManager } from './AssetManager.sol';

contract AssetManagerEntrypoint is
  IAssetManagerEntrypoint,
  IMessageRecipient,
  Ownable2StepUpgradeable,
  GasRouter,
  UUPSUpgradeable,
  Versioned
{
  using Message for *;
  using Conv for *;

  IAssetManager internal immutable _assetManager;
  ICrossChainRegistry internal immutable _ccRegistry;

  modifier onlyAssetManager() {
    require(_msgSender() == address(_assetManager), StdError.InvalidAddress('AssetManager'));
    _;
  }

  modifier onlyDispatchable(uint256 chainId) {
    require(_ccRegistry.isRegisteredChain(chainId), ICrossChainRegistry.ICrossChainRegistry__NotRegistered());
    require(
      _ccRegistry.mitosisVaultEntrypointEnrolled(chainId),
      ICrossChainRegistry.ICrossChainRegistry__MitosisVaultEntrypointNotEnrolled()
    );
    _;
  }

  constructor(address mailbox, address assetManager_, address ccRegistry_) GasRouter(mailbox) initializer {
    _assetManager = IAssetManager(assetManager_);
    _ccRegistry = ICrossChainRegistry(ccRegistry_);
  }

  function initialize(address owner_, address hook, address ism) public initializer {
    __UUPSUpgradeable_init();

    __Ownable_init(_msgSender());
    __Ownable2Step_init();

    _MailboxClient_initialize(hook, ism);
    _transferOwnership(owner_);
  }

  receive() external payable { }

  function assetManager() external view returns (IAssetManager) {
    return _assetManager;
  }

  function branchDomain(uint256 chainId) external view returns (uint32) {
    return _ccRegistry.hyperlaneDomain(chainId);
  }

  function branchMitosisVault(uint256 chainId) external view returns (address) {
    return _ccRegistry.mitosisVault(chainId);
  }

  function branchMitosisVaultEntrypoint(uint256 chainId) external view returns (address) {
    return _ccRegistry.mitosisVaultEntrypoint(chainId);
  }

  function quoteInitializeAsset(uint256 chainId, address branchAsset) external view returns (uint256) {
    bytes memory enc = MsgInitializeAsset({ asset: branchAsset.toBytes32() }).encode();
    return _quoteToBranch(chainId, MsgType.MsgInitializeAsset, enc);
  }

  function quoteInitializeMatrix(uint256 chainId, address matrixVault, address branchAsset)
    external
    view
    returns (uint256)
  {
    bytes memory enc =
      MsgInitializeMatrix({ matrixVault: matrixVault.toBytes32(), asset: branchAsset.toBytes32() }).encode();
    return _quoteToBranch(chainId, MsgType.MsgInitializeMatrix, enc);
  }

  function quoteWithdraw(uint256 chainId, address branchAsset, address to, uint256 amount)
    external
    view
    returns (uint256)
  {
    bytes memory enc = MsgWithdraw({ asset: branchAsset.toBytes32(), to: to.toBytes32(), amount: amount }).encode();
    return _quoteToBranch(chainId, MsgType.MsgWithdraw, enc);
  }

  function quoteAllocateMatrix(uint256 chainId, address matrixVault, uint256 amount) external view returns (uint256) {
    bytes memory enc = MsgAllocateMatrix({ matrixVault: matrixVault.toBytes32(), amount: amount }).encode();
    return _quoteToBranch(chainId, MsgType.MsgAllocateMatrix, enc);
  }

  function _quoteToBranch(uint256 chainId, MsgType msgType, bytes memory enc) internal view returns (uint256) {
    uint32 hplDomain = _ccRegistry.hyperlaneDomain(chainId);
    uint96 action = uint96(msgType);
    uint256 fee = _GasRouter_quoteDispatch(hplDomain, action, enc, address(hook()));
    return fee;
  }

  //=========== NOTE: ASSETMANAGER FUNCTIONS ===========//

  function initializeAsset(uint256 chainId, address branchAsset)
    external
    payable
    onlyAssetManager
    onlyDispatchable(chainId)
  {
    bytes memory enc = MsgInitializeAsset({ asset: branchAsset.toBytes32() }).encode();
    _dispatchToBranch(chainId, MsgType.MsgInitializeAsset, enc);
  }

  function initializeMatrix(uint256 chainId, address matrixVault, address branchAsset)
    external
    payable
    onlyAssetManager
    onlyDispatchable(chainId)
  {
    bytes memory enc =
      MsgInitializeMatrix({ matrixVault: matrixVault.toBytes32(), asset: branchAsset.toBytes32() }).encode();
    _dispatchToBranch(chainId, MsgType.MsgInitializeMatrix, enc);
  }

  function withdraw(uint256 chainId, address branchAsset, address to, uint256 amount)
    external
    payable
    onlyAssetManager
    onlyDispatchable(chainId)
  {
    bytes memory enc = MsgWithdraw({ asset: branchAsset.toBytes32(), to: to.toBytes32(), amount: amount }).encode();
    _dispatchToBranch(chainId, MsgType.MsgWithdraw, enc);
  }

  function allocateMatrix(uint256 chainId, address matrixVault, uint256 amount)
    external
    payable
    onlyAssetManager
    onlyDispatchable(chainId)
  {
    bytes memory enc = MsgAllocateMatrix({ matrixVault: matrixVault.toBytes32(), amount: amount }).encode();
    _dispatchToBranch(chainId, MsgType.MsgAllocateMatrix, enc);
  }

  function _dispatchToBranch(uint256 chainId, MsgType msgType, bytes memory enc) internal {
    uint32 hplDomain = _ccRegistry.hyperlaneDomain(chainId);

    uint96 action = uint96(msgType);
    uint256 fee = _GasRouter_quoteDispatch(hplDomain, action, enc, address(hook()));
    _GasRouter_dispatch(hplDomain, action, fee, enc, address(hook()));
  }

  //=========== NOTE: HANDLER FUNCTIONS ===========//

  function _handle(uint32 origin, bytes32 sender, bytes calldata msg_) internal override {
    uint256 chainId = _ccRegistry.chainId(origin);
    require(chainId != 0, ICrossChainRegistry.ICrossChainRegistry__NotRegistered());

    address entrypoint = _ccRegistry.mitosisVaultEntrypoint(chainId);
    require(sender.toAddress() == entrypoint, ICrossChainRegistry.ICrossChainRegistry__NotRegistered());

    MsgType msgType = msg_.msgType();

    if (msgType == MsgType.MsgDeposit) {
      MsgDeposit memory decoded = msg_.decodeDeposit();
      _assetManager.deposit(chainId, decoded.asset.toAddress(), decoded.to.toAddress(), decoded.amount);
      return;
    }

    if (msgType == MsgType.MsgDepositWithSupplyMatrix) {
      MsgDepositWithSupplyMatrix memory decoded = msg_.decodeDepositWithSupplyMatrix();
      _assetManager.depositWithSupplyMatrix(
        chainId, decoded.asset.toAddress(), decoded.to.toAddress(), decoded.matrixVault.toAddress(), decoded.amount
      );
      return;
    }

    if (msgType == MsgType.MsgDeallocateMatrix) {
      MsgDeallocateMatrix memory decoded = msg_.decodeDeallocateMatrix();
      _assetManager.deallocateMatrix(chainId, decoded.matrixVault.toAddress(), decoded.amount);
      return;
    }

    if (msgType == MsgType.MsgSettleMatrixYield) {
      MsgSettleMatrixYield memory decoded = msg_.decodeSettleMatrixYield();
      _assetManager.settleMatrixYield(chainId, decoded.matrixVault.toAddress(), decoded.amount);
      return;
    }

    if (msgType == MsgType.MsgSettleMatrixLoss) {
      MsgSettleMatrixLoss memory decoded = msg_.decodeSettleMatrixLoss();
      _assetManager.settleMatrixLoss(chainId, decoded.matrixVault.toAddress(), decoded.amount);
      return;
    }

    if (msgType == MsgType.MsgSettleMatrixExtraRewards) {
      MsgSettleMatrixExtraRewards memory decoded = msg_.decodeSettleMatrixExtraRewards();
      _assetManager.settleMatrixExtraRewards(
        chainId, decoded.matrixVault.toAddress(), decoded.reward.toAddress(), decoded.amount
      );
      return;
    }
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function _authorizeUpgrade(address) internal override onlyOwner { }

  function _authorizeConfigureGas(address sender) internal view override {
    require(sender == owner() || sender == address(_ccRegistry), StdError.Unauthorized());
  }

  function _authorizeConfigureRoute(address sender) internal view override {
    require(sender == owner() || sender == address(_ccRegistry), StdError.Unauthorized());
  }

  function _authorizeManageMailbox(address) internal override onlyOwner { }
}
