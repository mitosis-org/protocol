// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IERC20 } from '@oz/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz/token/ERC20/utils/SafeERC20.sol';
import { Address } from '@oz/utils/Address.sol';
import { AccessControlEnumerableUpgradeable } from '@ozu/access/extensions/AccessControlEnumerableUpgradeable.sol';
import { ReentrancyGuardUpgradeable } from '@ozu/utils/ReentrancyGuardUpgradeable.sol';

import { IMitosisVaultEntrypoint } from '../interfaces/branch/IMitosisVaultEntrypoint.sol';
import { IMitosisVaultVLF, VLFAction } from '../interfaces/branch/IMitosisVaultVLF.sol';
import { INativeWrappedToken } from '../interfaces/branch/INativeWrappedToken.sol';
import { IVLFStrategyExecutor } from '../interfaces/branch/strategy/IVLFStrategyExecutor.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';
import { Pausable } from '../lib/Pausable.sol';
import { StdError } from '../lib/StdError.sol';

abstract contract MitosisVaultVLF is
  IMitosisVaultVLF,
  Pausable,
  AccessControlEnumerableUpgradeable,
  ReentrancyGuardUpgradeable
{
  using ERC7201Utils for string;
  using SafeERC20 for IERC20;

  struct VLFInfo {
    bool initialized;
    address asset;
    address strategyExecutor;
    uint256 availableLiquidity;
    mapping(VLFAction => bool) isHalted;
  }

  struct VLFStorageV1 {
    mapping(address hubVLFVault => VLFInfo) vlfs;
  }

  string private constant _NAMESPACE = 'mitosis.storage.MitosisVault.VLF.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getVLFStorageV1() private view returns (VLFStorageV1 storage $) {
    bytes32 slot = _slot;
    assembly {
      $.slot := slot
    }
  }

  //=========== NOTE: View ===========//

  function isVLFActionHalted(address hubVLFVault, VLFAction action) external view returns (bool) {
    return _isVLFHalted(_getVLFStorageV1(), hubVLFVault, action);
  }

  function isVLFInitialized(address hubVLFVault) external view returns (bool) {
    return _isVLFInitialized(_getVLFStorageV1(), hubVLFVault);
  }

  function availableVLF(address hubVLFVault) external view returns (uint256) {
    return _getVLFStorageV1().vlfs[hubVLFVault].availableLiquidity;
  }

  function vlfStrategyExecutor(address hubVLFVault) external view returns (address) {
    return _getVLFStorageV1().vlfs[hubVLFVault].strategyExecutor;
  }

  function quoteDepositWithSupplyVLF(address asset, address to, address hubVLFVault, uint256 amount)
    external
    view
    returns (uint256)
  {
    return _entrypoint().quoteDepositWithSupplyVLF(asset, to, hubVLFVault, amount);
  }

  function quoteDeallocateVLF(address hubVLFVault, uint256 amount) external view returns (uint256) {
    return _entrypoint().quoteDeallocateVLF(hubVLFVault, amount);
  }

  function quoteSettleVLFYield(address hubVLFVault, uint256 amount) external view returns (uint256) {
    return _entrypoint().quoteSettleVLFYield(hubVLFVault, amount);
  }

  function quoteSettleVLFLoss(address hubVLFVault, uint256 amount) external view returns (uint256) {
    return _entrypoint().quoteSettleVLFLoss(hubVLFVault, amount);
  }

  function quoteSettleVLFExtraRewards(address hubVLFVault, address reward, uint256 amount)
    external
    view
    returns (uint256)
  {
    return _entrypoint().quoteSettleVLFExtraRewards(hubVLFVault, reward, amount);
  }

  //=========== NOTE: Asset ===========//

  function _entrypoint() internal view virtual returns (IMitosisVaultEntrypoint);

  function _deposit(address asset, address to, uint256 amount) internal virtual returns (uint256 gasPaid);

  function _assertAssetInitialized(address asset) internal view virtual;

  /// @dev _msgSender() must be able to receive native token, or provided msg.value must be the same as the gas needed
  function depositWithSupplyVLF(address asset, address to, address hubVLFVault, uint256 amount)
    external
    payable
    whenNotPaused
    nonReentrant
  {
    IMitosisVaultEntrypoint entry = _entrypoint();

    uint256 gasPaid = _deposit(asset, to, amount);
    uint256 gasNeeded = entry.quoteDepositWithSupplyVLF(asset, to, hubVLFVault, amount);
    require(gasNeeded <= gasPaid, StdError.InvalidParameter('gasNeeded > gasPaid'));

    VLFStorageV1 storage $ = _getVLFStorageV1();
    _assertVLFInitialized($, hubVLFVault);
    require(asset == $.vlfs[hubVLFVault].asset, IMitosisVaultVLF__InvalidVLF(hubVLFVault, asset));

    entry.depositWithSupplyVLF{ value: gasNeeded }(asset, to, hubVLFVault, amount);
    if (gasPaid > gasNeeded) Address.sendValue(payable(_msgSender()), gasPaid - gasNeeded);

    emit VLFDepositedWithSupply(asset, to, hubVLFVault, amount);
  }

  //=========== NOTE: VLF Lifecycle ===========//

  function initializeVLF(address hubVLFVault, address asset) external whenNotPaused {
    require(address(_entrypoint()) == _msgSender(), StdError.Unauthorized());

    VLFStorageV1 storage $ = _getVLFStorageV1();

    _assertVLFNotInitialized($, hubVLFVault);
    _assertAssetInitialized(asset);

    $.vlfs[hubVLFVault].initialized = true;
    $.vlfs[hubVLFVault].asset = asset;

    emit VLFInitialized(hubVLFVault, asset);
  }

  function allocateVLF(address hubVLFVault, uint256 amount) external whenNotPaused {
    require(address(_entrypoint()) == _msgSender(), StdError.Unauthorized());

    VLFStorageV1 storage $ = _getVLFStorageV1();
    _assertVLFInitialized($, hubVLFVault);

    $.vlfs[hubVLFVault].availableLiquidity += amount;

    emit VLFAllocated(hubVLFVault, amount);
  }

  /// @dev _msgSender() must be able to receive native token, or provided msg.value must be the same as the gas needed
  function deallocateVLF(address hubVLFVault, uint256 amount) external payable whenNotPaused nonReentrant {
    VLFStorageV1 storage $ = _getVLFStorageV1();

    _assertVLFInitialized($, hubVLFVault);
    _assertOnlyStrategyExecutor($, hubVLFVault);

    $.vlfs[hubVLFVault].availableLiquidity -= amount;

    IMitosisVaultEntrypoint entry = _entrypoint();

    uint256 gasPaid = msg.value;
    uint256 gasNeeded = entry.quoteDeallocateVLF(hubVLFVault, amount);
    require(gasNeeded <= gasPaid, StdError.InvalidParameter('gasNeeded > gasPaid'));

    entry.deallocateVLF{ value: gasNeeded }(hubVLFVault, amount);
    if (gasPaid > gasNeeded) Address.sendValue(payable(_msgSender()), gasPaid - gasNeeded);

    emit VLFDeallocated(hubVLFVault, amount);
  }

  function fetchVLF(address hubVLFVault, uint256 amount) external whenNotPaused {
    VLFStorageV1 storage $ = _getVLFStorageV1();

    _assertVLFInitialized($, hubVLFVault);
    _assertOnlyStrategyExecutor($, hubVLFVault);
    _assertNotHalted($, hubVLFVault, VLFAction.FetchVLF);

    VLFInfo storage vlfInfo = $.vlfs[hubVLFVault];

    vlfInfo.availableLiquidity -= amount;
    IERC20(vlfInfo.asset).safeTransfer(vlfInfo.strategyExecutor, amount);

    emit VLFFetched(hubVLFVault, amount);
  }

  function returnVLF(address hubVLFVault, uint256 amount) external whenNotPaused {
    VLFStorageV1 storage $ = _getVLFStorageV1();

    _assertVLFInitialized($, hubVLFVault);
    _assertOnlyStrategyExecutor($, hubVLFVault);

    VLFInfo storage vlfInfo = $.vlfs[hubVLFVault];

    vlfInfo.availableLiquidity += amount;
    IERC20(vlfInfo.asset).safeTransferFrom(vlfInfo.strategyExecutor, address(this), amount);

    emit VLFReturned(hubVLFVault, amount);
  }

  /// @dev _msgSender() must be able to receive native token, or provided msg.value must be the same as the gas needed
  function settleVLFYield(address hubVLFVault, uint256 amount) external payable whenNotPaused nonReentrant {
    VLFStorageV1 storage $ = _getVLFStorageV1();

    _assertVLFInitialized($, hubVLFVault);
    _assertOnlyStrategyExecutor($, hubVLFVault);

    IMitosisVaultEntrypoint entry = _entrypoint();

    uint256 gasPaid = msg.value;
    uint256 gasNeeded = entry.quoteSettleVLFYield(hubVLFVault, amount);
    require(gasNeeded <= gasPaid, StdError.InvalidParameter('gasNeeded > gasPaid'));

    entry.settleVLFYield{ value: gasNeeded }(hubVLFVault, amount);
    if (gasPaid > gasNeeded) Address.sendValue(payable(_msgSender()), gasPaid - gasNeeded);

    emit VLFYieldSettled(hubVLFVault, amount);
  }

  /// @dev _msgSender() must be able to receive native token, or provided msg.value must be the same as the gas needed
  function settleVLFLoss(address hubVLFVault, uint256 amount) external payable whenNotPaused nonReentrant {
    VLFStorageV1 storage $ = _getVLFStorageV1();

    _assertVLFInitialized($, hubVLFVault);
    _assertOnlyStrategyExecutor($, hubVLFVault);

    IMitosisVaultEntrypoint entry = _entrypoint();

    uint256 gasPaid = msg.value;
    uint256 gasNeeded = entry.quoteSettleVLFLoss(hubVLFVault, amount);
    require(gasNeeded <= gasPaid, StdError.InvalidParameter('gasNeeded > gasPaid'));

    entry.settleVLFLoss{ value: gasNeeded }(hubVLFVault, amount);
    if (gasPaid > gasNeeded) Address.sendValue(payable(_msgSender()), gasPaid - gasNeeded);

    emit VLFLossSettled(hubVLFVault, amount);
  }

  /// @dev _msgSender() must be able to receive native token, or provided msg.value must be the same as the gas needed
  function settleVLFExtraRewards(address hubVLFVault, address reward, uint256 amount)
    external
    payable
    whenNotPaused
    nonReentrant
  {
    VLFStorageV1 storage $ = _getVLFStorageV1();

    _assertVLFInitialized($, hubVLFVault);
    _assertOnlyStrategyExecutor($, hubVLFVault);
    _assertAssetInitialized(reward);
    require(reward != $.vlfs[hubVLFVault].asset, StdError.InvalidAddress('reward'));

    IERC20(reward).safeTransferFrom(_msgSender(), address(this), amount);

    IMitosisVaultEntrypoint entry = _entrypoint();

    uint256 gasPaid = msg.value;
    uint256 gasNeeded = entry.quoteSettleVLFExtraRewards(hubVLFVault, reward, amount);
    require(gasNeeded <= gasPaid, StdError.InvalidParameter('gasNeeded > gasPaid'));

    entry.settleVLFExtraRewards{ value: gasNeeded }(hubVLFVault, reward, amount);
    if (gasPaid > gasNeeded) Address.sendValue(payable(_msgSender()), gasPaid - gasNeeded);

    emit VLFExtraRewardsSettled(hubVLFVault, reward, amount);
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function haltVLF(address hubVLFVault, VLFAction action) external onlyRole(DEFAULT_ADMIN_ROLE) {
    VLFStorageV1 storage $ = _getVLFStorageV1();
    _assertVLFInitialized($, hubVLFVault);
    return _haltVLF($, hubVLFVault, action);
  }

  function resumeVLF(address hubVLFVault, VLFAction action) external onlyRole(DEFAULT_ADMIN_ROLE) {
    VLFStorageV1 storage $ = _getVLFStorageV1();
    _assertVLFInitialized($, hubVLFVault);
    return _resumeVLF($, hubVLFVault, action);
  }

  function setVLFStrategyExecutor(address hubVLFVault, address strategyExecutor_) external onlyRole(DEFAULT_ADMIN_ROLE) {
    VLFStorageV1 storage $ = _getVLFStorageV1();
    VLFInfo storage vlfInfo = $.vlfs[hubVLFVault];

    _assertVLFInitialized($, hubVLFVault);

    if (vlfInfo.strategyExecutor != address(0)) {
      // NOTE: no way to check if every extra rewards are settled.
      bool drained = IVLFStrategyExecutor(vlfInfo.strategyExecutor).totalBalance() == 0
        && IVLFStrategyExecutor(vlfInfo.strategyExecutor).storedTotalBalance() == 0;
      require(drained, IMitosisVaultVLF__StrategyExecutorNotDrained(hubVLFVault, vlfInfo.strategyExecutor));
    }

    require(
      hubVLFVault == IVLFStrategyExecutor(strategyExecutor_).hubVLFVault(),
      StdError.InvalidId('VLFStrategyExecutor.hubVLFVault')
    );
    require(
      address(this) == address(IVLFStrategyExecutor(strategyExecutor_).vault()),
      StdError.InvalidAddress('VLFStrategyExecutor.vault')
    );
    require(
      vlfInfo.asset == address(IVLFStrategyExecutor(strategyExecutor_).asset()),
      StdError.InvalidAddress('VLFStrategyExecutor.asset')
    );

    vlfInfo.strategyExecutor = strategyExecutor_;
    emit VLFStrategyExecutorSet(hubVLFVault, strategyExecutor_);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _isVLFHalted(VLFStorageV1 storage $, address hubVLFVault, VLFAction action) internal view returns (bool) {
    return $.vlfs[hubVLFVault].isHalted[action];
  }

  function _haltVLF(VLFStorageV1 storage $, address hubVLFVault, VLFAction action) internal {
    $.vlfs[hubVLFVault].isHalted[action] = true;
    emit VLFHalted(hubVLFVault, action);
  }

  function _resumeVLF(VLFStorageV1 storage $, address hubVLFVault, VLFAction action) internal {
    $.vlfs[hubVLFVault].isHalted[action] = false;
    emit VLFResumed(hubVLFVault, action);
  }

  function _assertNotHalted(VLFStorageV1 storage $, address hubVLFVault, VLFAction action) internal view {
    require(!_isVLFHalted($, hubVLFVault, action), StdError.Halted());
  }

  function _isVLFInitialized(VLFStorageV1 storage $, address hubVLFVault) internal view returns (bool) {
    return $.vlfs[hubVLFVault].initialized;
  }

  function _assertVLFInitialized(VLFStorageV1 storage $, address hubVLFVault) internal view {
    require(_isVLFInitialized($, hubVLFVault), IMitosisVaultVLF__VLFNotInitialized(hubVLFVault));
  }

  function _assertVLFNotInitialized(VLFStorageV1 storage $, address hubVLFVault) internal view {
    require(!_isVLFInitialized($, hubVLFVault), IMitosisVaultVLF__VLFAlreadyInitialized(hubVLFVault));
  }

  function _assertOnlyStrategyExecutor(VLFStorageV1 storage $, address hubVLFVault) internal view {
    require(_msgSender() == $.vlfs[hubVLFVault].strategyExecutor, StdError.Unauthorized());
  }
}
