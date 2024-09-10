// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { Router } from '@hpl-v5/client/Router.sol';
import { IMessageRecipient } from '@hpl-v5/interfaces/IMessageRecipient.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';
import { PausableUpgradeable } from '@ozu-v5/utils/PausableUpgradeable.sol';

import { IMitosisVault } from '../interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '../interfaces/branch/IMitosisVaultEntrypoint.sol';
import { Conv } from '../lib/Conv.sol';
import { StdError } from '../lib/StdError.sol';
import '../message/Message.sol';

// TODO(thai): consider to make our own contract (`HyperlaneConnector`) instead of using `Router`.

contract MitosisVaultEntrypoint is
  IMitosisVaultEntrypoint,
  IMessageRecipient,
  Router,
  PausableUpgradeable,
  Ownable2StepUpgradeable
{
  using Message for *;
  using Conv for *;

  IMitosisVault internal immutable _vault;
  uint32 internal immutable _mitosisDomain;
  bytes32 internal immutable _mitosisAddr;

  modifier onlyVault() {
    require(_msgSender() == address(_vault), StdError.InvalidAddress('vault'));
    _;
  }

  constructor(address mailbox, address vault_, uint32 mitosisDomain_, bytes32 mitosisAddr_) Router(mailbox) initializer {
    _vault = IMitosisVault(vault_);
    _mitosisDomain = mitosisDomain_;
    _mitosisAddr = mitosisAddr_;
  }

  function initialize(address owner_, address hook, address ism) public initializer {
    _MailboxClient_initialize(hook, ism, owner_);
    __Pausable_init();
    __Ownable2Step_init();
    _transferOwnership(owner_);

    _enrollRemoteRouter(_mitosisDomain, _mitosisAddr);
  }

  function vault() external view returns (IMitosisVault vault_) {
    return _vault;
  }

  function mitosisDomain() external view returns (uint32 mitosisDomain_) {
    return _mitosisDomain;
  }

  function mitosisAddr() external view returns (bytes32 mitosisAddr_) {
    return _mitosisAddr;
  }

  //=========== NOTE: VAULT FUNCTIONS ===========//

  function deposit(address asset, address to, uint256 amount) external onlyVault {
    bytes memory enc = MsgDeposit({ asset: asset.toBytes32(), to: to.toBytes32(), amount: amount }).encode();
    _dispatchToMitosis(enc);
  }

  function deallocateEOL(uint256 eolId, uint256 amount) external onlyVault {
    bytes memory enc = MsgDeallocateEOL({ eolId: eolId, amount: amount }).encode();
    _dispatchToMitosis(enc);
  }

  function settleYield(uint256 eolId, uint256 amount) external onlyVault {
    bytes memory enc = MsgSettleYield({ eolId: eolId, amount: amount }).encode();
    _dispatchToMitosis(enc);
  }

  function settleLoss(uint256 eolId, uint256 amount) external onlyVault {
    bytes memory enc = MsgSettleLoss({ eolId: eolId, amount: amount }).encode();
    _dispatchToMitosis(enc);
  }

  function settleExtraRewards(uint256 eolId, address reward, uint256 amount) external onlyVault {
    bytes memory enc = MsgSettleExtraRewards({ eolId: eolId, reward: reward.toBytes32(), amount: amount }).encode();
    _dispatchToMitosis(enc);
  }

  function _dispatchToMitosis(bytes memory enc) internal {
    // TODO(thai): consider hyperlane fee
    _dispatch(_mitosisDomain, enc);
  }

  //=========== NOTE: HANDLER FUNCTIONS ===========//

  function _handle(uint32 origin, bytes32 sender, bytes calldata msg_) internal override {
    require(origin == _mitosisDomain && sender == _mitosisAddr, StdError.Unauthorized());

    MsgType msgType = msg_.msgType();

    if (msgType == MsgType.MsgInitializeAsset) {
      MsgInitializeAsset memory decoded = msg_.decodeInitializeAsset();
      _vault.initializeAsset(decoded.asset.toAddress());
    }

    if (msgType == MsgType.MsgRedeem) {
      MsgRedeem memory decoded = msg_.decodeRedeem();
      _vault.redeem(decoded.asset.toAddress(), decoded.to.toAddress(), decoded.amount);
    }

    if (msgType == MsgType.MsgInitializeEOL) {
      MsgInitializeEOL memory decoded = msg_.decodeInitializeEOL();
      _vault.initializeEOL(decoded.eolId, decoded.asset.toAddress());
    }

    if (msgType == MsgType.MsgAllocateEOL) {
      MsgAllocateEOL memory decoded = msg_.decodeAllocateEOL();
      _vault.allocateEOL(decoded.eolId, decoded.amount);
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
