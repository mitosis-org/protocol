// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IMessageRecipient } from '@hpl-v5/interfaces/IMessageRecipient.sol';
import { Router } from '@hpl-v5/client/Router.sol';
import { PausableUpgradeable } from '@ozu-v5/utils/PausableUpgradeable.sol';
import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IAssetManagerEntrypoint } from '../../interfaces/hub/core/IAssetManagerEntrypoint.sol';
import { IAssetManager } from '../../interfaces/hub/core/IAssetManager.sol';
import { ICrossChainRegistry } from '../../interfaces/hub/cross-chain/ICrossChainRegistry.sol';
import { AssetManager } from './AssetManager.sol';
import { StdError } from '../../lib/StdError.sol';
import { Conv } from '../../lib/Conv.sol';
import '../../message/Message.sol';

// TODO(thai): consider to make our own contract (`HyperlaneConnector`) instead of using `Router`.

contract AssetManagerEntrypoint is
  IAssetManagerEntrypoint,
  IMessageRecipient,
  Router,
  PausableUpgradeable,
  Ownable2StepUpgradeable
{
  using Message for *;
  using Conv for *;

  IAssetManager internal immutable _assetManager;
  ICrossChainRegistry internal immutable _ccRegistry;

  modifier onlyAssetManager() {
    if (msg.sender != address(_assetManager)) revert StdError.InvalidAddress('AssetManager');
    _;
  }

  modifier onlyDispachable(uint256 chainId) {
    if (!_ccRegistry.isRegisteredChain(chainId)) revert ICrossChainRegistry.ICrossChainRegistry__NotRegistered();
    if (!_ccRegistry.entrypointEnrolled(chainId)) revert ICrossChainRegistry.ICrossChainRegistry__NotEnrolled();
    _;
  }

  constructor(address mailbox, address assetManager_, address ccRegistry_) Router(mailbox) initializer {
    _assetManager = IAssetManager(assetManager_);
    _ccRegistry = ICrossChainRegistry(ccRegistry_);
  }

  function initialize(address owner_, address hook, address ism) public initializer {
    _MailboxClient_initialize(hook, ism, owner_);
    __Pausable_init();
    __Ownable2Step_init();
    _transferOwnership(owner_);
  }

  function assetManager() external view returns (IAssetManager assetManger_) {
    return _assetManager;
  }

  function branchDomain(uint256 chainId) external view returns (uint32) {
    return _ccRegistry.hyperlaneDomain(chainId);
  }

  function branchVault(uint256 chainId) external view returns (address) {
    return _ccRegistry.vault(chainId);
  }

  function branchEntrypointAddr(uint256 chainId) external view returns (address) {
    return _ccRegistry.entrypoint(chainId);
  }

  //=========== NOTE: ASSETMANAGER FUNCTIONS ===========//

  function initializeAsset(uint256 chainId, address branchAsset) external onlyAssetManager onlyDispachable(chainId) {
    bytes memory enc = MsgInitializeAsset({ asset: branchAsset.toBytes32() }).encode();
    _dispatchToBranch(chainId, enc);
  }

  function initializeEOL(uint256 chainId, uint256 eolId, address branchAsset)
    external
    onlyAssetManager
    onlyDispachable(chainId)
  {
    bytes memory enc = MsgInitializeEOL({ eolId: eolId, asset: branchAsset.toBytes32() }).encode();
    _dispatchToBranch(chainId, enc);
  }

  function redeem(uint256 chainId, address branchAsset, address to, uint256 amount)
    external
    onlyAssetManager
    onlyDispachable(chainId)
  {
    bytes memory enc = MsgRedeem({ asset: branchAsset.toBytes32(), to: to.toBytes32(), amount: amount }).encode();
    _dispatchToBranch(chainId, enc);
  }

  function allocateEOL(uint256 chainId, uint256 eolId, uint256 amount)
    external
    onlyAssetManager
    onlyDispachable(chainId)
  {
    bytes memory enc = MsgAllocateEOL({ eolId: eolId, amount: amount }).encode();
    _dispatchToBranch(chainId, enc);
  }

  function _dispatchToBranch(uint256 chainId, bytes memory enc) internal {
    // TODO(thai): consider hyperlane fee
    uint32 hplDomain = _ccRegistry.hyperlaneDomain(chainId);
    _dispatch(hplDomain, enc);
  }

  //=========== NOTE: HANDLER FUNCTIONS ===========//

  function _handle(uint32 origin, bytes32 sender, bytes calldata msg_) internal override {
    uint256 chainId = _ccRegistry.chainId(origin);
    if (chainId == 0) revert ICrossChainRegistry.ICrossChainRegistry__NotRegistered();

    address vault = _ccRegistry.vault(chainId);
    if (sender.toAddress() != vault) revert ICrossChainRegistry.ICrossChainRegistry__NotRegistered();

    MsgType msgType = msg_.msgType();

    if (msgType == MsgType.MsgDeposit) {
      MsgDeposit memory decoded = msg_.decodeDeposit();
      _assetManager.deposit(chainId, decoded.asset.toAddress(), decoded.to.toAddress(), decoded.amount);
    }

    if (msgType == MsgType.MsgDeallocateEOL) {
      MsgDeallocateEOL memory decoded = msg_.decodeDeallocateEOL();
      _assetManager.deallocateEOL(chainId, decoded.eolId, decoded.amount);
    }

    if (msgType == MsgType.MsgSettleYield) {
      MsgSettleYield memory decoded = msg_.decodeSettleYield();
      _assetManager.settleYield(chainId, decoded.eolId, decoded.amount);
    }

    if (msgType == MsgType.MsgSettleLoss) {
      MsgSettleLoss memory decoded = msg_.decodeSettleLoss();
      _assetManager.settleLoss(chainId, decoded.eolId, decoded.amount);
    }

    if (msgType == MsgType.MsgSettleExtraRewards) {
      MsgSettleExtraRewards memory decoded = msg_.decodeSettleExtraRewards();
      _assetManager.settleExtraRewards(chainId, decoded.eolId, decoded.reward.toAddress(), decoded.amount);
    }
  }

  //=========== NOTE: OwnableUpgradeable & Ownable2StepUpgradeable

  function transferOwnership(address owner) public override(Ownable2StepUpgradeable, OwnableUpgradeable) {
    Ownable2StepUpgradeable.transferOwnership(owner);
  }

  function _transferOwnership(address owner) internal override(Ownable2StepUpgradeable, OwnableUpgradeable) {
    Ownable2StepUpgradeable._transferOwnership(owner);
  }
}
