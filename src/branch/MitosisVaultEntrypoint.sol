// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IMessageRecipient } from '@hpl/interfaces/IMessageRecipient.sol';

import { Ownable2StepUpgradeable } from '@ozu/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu/proxy/utils/UUPSUpgradeable.sol';

import { GasRouter } from '../external/hyperlane/GasRouter.sol';
import { IMitosisVault } from '../interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '../interfaces/branch/IMitosisVaultEntrypoint.sol';
import { Conv } from '../lib/Conv.sol';
import { StdError } from '../lib/StdError.sol';
import '../message/Message.sol';

contract MitosisVaultEntrypoint is
  IMitosisVaultEntrypoint,
  IMessageRecipient,
  Ownable2StepUpgradeable,
  GasRouter,
  UUPSUpgradeable
{
  using Message for *;
  using Conv for *;

  IMitosisVault internal immutable _vault;
  uint32 internal immutable _mitosisDomain;
  bytes32 internal immutable _mitosisAddr; // Hub.AssetManagerEntrypoint

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
    __UUPSUpgradeable_init();

    __Ownable_init(_msgSender());
    __Ownable2Step_init();

    _MailboxClient_initialize(hook, ism);
    _transferOwnership(owner_);
    _enrollRemoteRouter(_mitosisDomain, _mitosisAddr);
  }

  function vault() external view returns (IMitosisVault) {
    return _vault;
  }

  function mitosisDomain() external view returns (uint32) {
    return _mitosisDomain;
  }

  function mitosisAddr() external view returns (bytes32) {
    return _mitosisAddr;
  }

  function quoteDeposit(address asset, address to, uint256 amount) external view returns (uint256) {
    bytes memory enc = MsgDeposit({ asset: asset.toBytes32(), to: to.toBytes32(), amount: amount }).encode();
    return _quoteToMitosis(enc, MsgType.MsgDeposit);
  }

  function quoteDepositWithSupplyMatrix(address asset, address to, address hubMatrixVault, uint256 amount)
    external
    view
    returns (uint256)
  {
    bytes memory enc = MsgDepositWithSupplyMatrix({
      asset: asset.toBytes32(),
      to: to.toBytes32(),
      matrixVault: hubMatrixVault.toBytes32(),
      amount: amount
    }).encode();
    return _quoteToMitosis(enc, MsgType.MsgDepositWithSupplyMatrix);
  }

  function quoteDepositWithSupplyEOL(address asset, address to, address hubEOLVault, uint256 amount)
    external
    view
    returns (uint256)
  {
    bytes memory enc = MsgDepositWithSupplyEOL({
      asset: asset.toBytes32(),
      to: to.toBytes32(),
      eolVault: hubEOLVault.toBytes32(),
      amount: amount
    }).encode();
    return _quoteToMitosis(enc, MsgType.MsgDepositWithSupplyEOL);
  }

  function quoteDeallocateMatrix(address hubMatrixVault, uint256 amount) external view returns (uint256) {
    bytes memory enc = MsgDeallocateMatrix({ matrixVault: hubMatrixVault.toBytes32(), amount: amount }).encode();
    return _quoteToMitosis(enc, MsgType.MsgDeallocateMatrix);
  }

  function quoteSettleMatrixYield(address hubMatrixVault, uint256 amount) external view returns (uint256) {
    bytes memory enc = MsgSettleMatrixYield({ matrixVault: hubMatrixVault.toBytes32(), amount: amount }).encode();
    return _quoteToMitosis(enc, MsgType.MsgSettleMatrixYield);
  }

  function quoteSettleMatrixLoss(address hubMatrixVault, uint256 amount) external view returns (uint256) {
    bytes memory enc = MsgSettleMatrixLoss({ matrixVault: hubMatrixVault.toBytes32(), amount: amount }).encode();
    return _quoteToMitosis(enc, MsgType.MsgSettleMatrixLoss);
  }

  function quoteSettleMatrixExtraRewards(address hubMatrixVault, address reward, uint256 amount)
    external
    view
    returns (uint256)
  {
    bytes memory enc = MsgSettleMatrixExtraRewards({
      matrixVault: hubMatrixVault.toBytes32(),
      reward: reward.toBytes32(),
      amount: amount
    }).encode();
    return _quoteToMitosis(enc, MsgType.MsgSettleMatrixExtraRewards);
  }

  function _quoteToMitosis(bytes memory enc, MsgType msgType) internal view returns (uint256) {
    uint96 action = uint96(msgType);
    uint256 fee = _GasRouter_quoteDispatch(_mitosisDomain, action, enc, address(hook()));
    return fee;
  }

  //=========== NOTE: VAULT FUNCTIONS ===========//

  function deposit(address asset, address to, uint256 amount) external payable onlyVault {
    bytes memory enc = MsgDeposit({ asset: asset.toBytes32(), to: to.toBytes32(), amount: amount }).encode();
    _dispatchToMitosis(enc, MsgType.MsgDeposit);
  }

  function depositWithSupplyMatrix(address asset, address to, address hubMatrixVault, uint256 amount)
    external
    payable
    onlyVault
  {
    bytes memory enc = MsgDepositWithSupplyMatrix({
      asset: asset.toBytes32(),
      to: to.toBytes32(),
      matrixVault: hubMatrixVault.toBytes32(),
      amount: amount
    }).encode();
    _dispatchToMitosis(enc, MsgType.MsgDepositWithSupplyMatrix);
  }

  function depositWithSupplyEOL(address asset, address to, address hubEOLVault, uint256 amount)
    external
    payable
    onlyVault
  {
    bytes memory enc = MsgDepositWithSupplyEOL({
      asset: asset.toBytes32(),
      to: to.toBytes32(),
      eolVault: hubEOLVault.toBytes32(),
      amount: amount
    }).encode();
    _dispatchToMitosis(enc, MsgType.MsgDepositWithSupplyEOL);
  }

  function deallocateMatrix(address hubMatrixVault, uint256 amount) external payable onlyVault {
    bytes memory enc = MsgDeallocateMatrix({ matrixVault: hubMatrixVault.toBytes32(), amount: amount }).encode();
    _dispatchToMitosis(enc, MsgType.MsgDeallocateMatrix);
  }

  function settleMatrixYield(address hubMatrixVault, uint256 amount) external payable onlyVault {
    bytes memory enc = MsgSettleMatrixYield({ matrixVault: hubMatrixVault.toBytes32(), amount: amount }).encode();
    _dispatchToMitosis(enc, MsgType.MsgSettleMatrixYield);
  }

  function settleMatrixLoss(address hubMatrixVault, uint256 amount) external payable onlyVault {
    bytes memory enc = MsgSettleMatrixLoss({ matrixVault: hubMatrixVault.toBytes32(), amount: amount }).encode();
    _dispatchToMitosis(enc, MsgType.MsgSettleMatrixLoss);
  }

  function settleMatrixExtraRewards(address hubMatrixVault, address reward, uint256 amount) external payable onlyVault {
    bytes memory enc = MsgSettleMatrixExtraRewards({
      matrixVault: hubMatrixVault.toBytes32(),
      reward: reward.toBytes32(),
      amount: amount
    }).encode();
    _dispatchToMitosis(enc, MsgType.MsgSettleMatrixExtraRewards);
  }

  function _dispatchToMitosis(bytes memory enc, MsgType msgType) internal {
    uint96 action = uint96(msgType);
    uint256 fee = _GasRouter_quoteDispatch(_mitosisDomain, action, enc, address(hook()));
    _GasRouter_dispatch(_mitosisDomain, action, fee, enc, address(hook()));
  }

  //=========== NOTE: HANDLER FUNCTIONS ===========//

  function _handle(uint32 origin, bytes32 sender, bytes calldata msg_) internal override {
    require(origin == _mitosisDomain && sender == _mitosisAddr, StdError.Unauthorized());

    MsgType msgType = msg_.msgType();

    if (msgType == MsgType.MsgInitializeAsset) {
      MsgInitializeAsset memory decoded = msg_.decodeInitializeAsset();
      _vault.initializeAsset(decoded.asset.toAddress());
    }

    if (msgType == MsgType.MsgWithdraw) {
      MsgWithdraw memory decoded = msg_.decodeWithdraw();
      _vault.withdraw(decoded.asset.toAddress(), decoded.to.toAddress(), decoded.amount);
    }

    if (msgType == MsgType.MsgInitializeMatrix) {
      MsgInitializeMatrix memory decoded = msg_.decodeInitializeMatrix();
      _vault.initializeMatrix(decoded.matrixVault.toAddress(), decoded.asset.toAddress());
    }

    if (msgType == MsgType.MsgAllocateMatrix) {
      MsgAllocateMatrix memory decoded = msg_.decodeAllocateMatrix();
      _vault.allocateMatrix(decoded.matrixVault.toAddress(), decoded.amount);
    }

    if (msgType == MsgType.MsgInitializeEOL) {
      MsgInitializeEOL memory decoded = msg_.decodeInitializeEOL();
      _vault.initializeEOL(decoded.eolVault.toAddress(), decoded.asset.toAddress());
    }
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function _authorizeUpgrade(address) internal override onlyOwner { }

  function _authorizeConfigureGas(address) internal override onlyOwner { }

  function _authorizeConfigureRoute(address) internal override onlyOwner { }

  function _authorizeManageMailbox(address) internal override onlyOwner { }
}
