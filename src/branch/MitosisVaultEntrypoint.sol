// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { GasRouter } from '@hpl-v5/client/GasRouter.sol';
import { IMessageRecipient } from '@hpl-v5/interfaces/IMessageRecipient.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';

import { IMitosisVault } from '../interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '../interfaces/branch/IMitosisVaultEntrypoint.sol';
import { Conv } from '../lib/Conv.sol';
import { StdError } from '../lib/StdError.sol';
import '../message/Message.sol';

// TODO(thai): consider to make our own contract (`HyperlaneConnector`) instead of using `GasRouter`.

contract MitosisVaultEntrypoint is IMitosisVaultEntrypoint, IMessageRecipient, GasRouter, Ownable2StepUpgradeable {
  using Message for *;
  using Conv for *;

  IMitosisVault internal immutable _vault;
  uint32 internal immutable _mitosisDomain;
  bytes32 internal immutable _mitosisAddr;

  modifier onlyVault() {
    require(_msgSender() == address(_vault), StdError.InvalidAddress('vault'));
    _;
  }

  constructor(address mailbox, address vault_, uint32 mitosisDomain_, bytes32 mitosisAddr_)
    GasRouter(mailbox)
    initializer
  {
    _vault = IMitosisVault(vault_);
    _mitosisDomain = mitosisDomain_;
    _mitosisAddr = mitosisAddr_;
  }

  function initialize(address owner_, address hook, address ism) public initializer {
    _MailboxClient_initialize(hook, ism, owner_);
    __Ownable2Step_init();
    _transferOwnership(owner_);

    _enrollRemoteRouter(_mitosisDomain, _mitosisAddr);
  }

  receive() external payable { }

  function vault() external view returns (IMitosisVault) {
    return _vault;
  }

  function mitosisDomain() external view returns (uint32) {
    return _mitosisDomain;
  }

  function mitosisAddr() external view returns (bytes32) {
    return _mitosisAddr;
  }

  //=========== NOTE: VAULT FUNCTIONS ===========//

  function deposit(address asset, address to, uint256 amount) external onlyVault {
    bytes memory enc = MsgDeposit({ asset: asset.toBytes32(), to: to.toBytes32(), amount: amount }).encode();
    _dispatchToMitosis(enc);
  }

  function depositWithMatrixSupply(address asset, address to, address hubMatrixBasketAsset, uint256 amount)
    external
    onlyVault
  {
    bytes memory enc = MsgDepositWithMatrixSupply({
      asset: asset.toBytes32(),
      to: to.toBytes32(),
      matrixBasketAsset: hubMatrixBasketAsset.toBytes32(),
      amount: amount
    }).encode();
    _dispatchToMitosis(enc);
  }

  function deallocateMatrixLiquidity(address hubMatrixBasketAsset, uint256 amount) external onlyVault {
    bytes memory enc =
      MsgDeallocateMatrixLiquidity({ matrixBasketAsset: hubMatrixBasketAsset.toBytes32(), amount: amount }).encode();
    _dispatchToMitosis(enc);
  }

  function settleMatrixYield(address hubMatrixBasketAsset, uint256 amount) external onlyVault {
    bytes memory enc =
      MsgSettleMatrixYield({ matrixBasketAsset: hubMatrixBasketAsset.toBytes32(), amount: amount }).encode();
    _dispatchToMitosis(enc);
  }

  function settleMatrixLoss(address hubMatrixBasketAsset, uint256 amount) external onlyVault {
    bytes memory enc =
      MsgSettleMatrixLoss({ matrixBasketAsset: hubMatrixBasketAsset.toBytes32(), amount: amount }).encode();
    _dispatchToMitosis(enc);
  }

  function settleMatrixExtraRewards(address hubMatrixBasketAsset, address reward, uint256 amount) external onlyVault {
    bytes memory enc = MsgSettleMatrixExtraRewards({
      matrixBasketAsset: hubMatrixBasketAsset.toBytes32(),
      reward: reward.toBytes32(),
      amount: amount
    }).encode();
    _dispatchToMitosis(enc);
  }

  function _dispatchToMitosis(bytes memory enc) internal {
    uint256 fee = _GasRouter_quoteDispatch(_mitosisDomain, enc, address(hook));
    _GasRouter_dispatch(_mitosisDomain, fee, enc, address(hook));
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

    if (msgType == MsgType.MsgInitializeMatrix) {
      MsgInitializeMatrix memory decoded = msg_.decodeInitializeMatrix();
      _vault.initializeMatrix(decoded.matrixBasketAsset.toAddress(), decoded.asset.toAddress());
    }

    if (msgType == MsgType.MsgAllocateMatrixLiquidity) {
      MsgAllocateMatrixLiquidity memory decoded = msg_.decodeAllocateMatrixLiquidity();
      _vault.allocateMatrixLiquidity(decoded.matrixBasketAsset.toAddress(), decoded.amount);
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
