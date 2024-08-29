// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Address } from '@oz-v5/utils/Address.sol';

import { PausableUpgradeable } from '@ozu-v5/utils/PausableUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { AssetAction, EOLAction, IMitosisVault } from '../interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '../interfaces/branch/IMitosisVaultEntrypoint.sol';
import { IStrategyExecutor } from '../interfaces/branch/strategy/IStrategyExecutor.sol';
import { MitosisVaultStorageV1 } from '../branch/storage/MitosisVaultStorageV1.sol';
import { StdError } from '../lib/StdError.sol';

// TODO(thai): add some view functions in MitosisVault

contract MitosisVault is IMitosisVault, PausableUpgradeable, Ownable2StepUpgradeable, MitosisVaultStorageV1 {
  using SafeERC20 for IERC20;
  using Address for address;

  //=========== NOTE: EVENT DEFINITIONS ===========//

  event AssetInitialized(address asset);

  event Deposited(address indexed asset, address indexed to, uint256 amount);
  event Redeemed(address indexed asset, address indexed to, uint256 amount);

  event EOLInitialized(uint256 eolId, address asset);

  event EOLAllocated(uint256 indexed eolId, uint256 amount);
  event EOLDeallocated(uint256 indexed eolId, uint256 amount);
  event EOLFetched(uint256 indexed eolId, uint256 amount);
  event EOLReturned(uint256 indexed eolId, uint256 amount);

  event YieldSettled(uint256 indexed eolId, uint256 amount);
  event LossSettled(uint256 indexed eolId, uint256 amount);
  event ExtraRewardsSettled(uint256 indexed eolId, address indexed reward, uint256 amount);

  event EntrypointSet(address entrypoint);
  event StrategyExecutorSet(uint256 indexed eolId, address indexed strategyExecutor);

  event Halted(address indexed asset, AssetAction action);
  event Resumed(address indexed asset, AssetAction action);

  event Halted(uint256 indexed eolId, EOLAction action);
  event Resumed(uint256 indexed eolId, EOLAction action);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error MitosisVault__AssetNotInitialized(address asset);
  error MitosisVault__AssetAlreadyInitialized(address asset);

  error MitosisVault__EOLNotInitialized(uint256 eolId);
  error MitosisVault__EOLAlreadyInitialized(uint256 eolId);

  error MitosisVault__StrategyExecutorNotDrained(uint256 eolId, address strategyExecutor);

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() {
    _disableInitializers();
  }

  fallback() external payable {
    revert StdError.Unauthorized();
  }

  receive() external payable {
    revert StdError.Unauthorized();
  }

  function initialize(address owner_) public initializer {
    __Pausable_init();
    __Ownable2Step_init();
    _transferOwnership(owner_);
  }

  //=========== NOTE: ASSET FUNCTIONS ===========//

  function initializeAsset(address asset) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertAssetNotInitialized($, asset);

    $.assets[asset].initialized = true;
    emit AssetInitialized(asset);

    // NOTE: we halt deposit by default.
    _halt($, asset, AssetAction.Deposit);
  }

  function deposit(address asset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertAssetInitialized($, asset);
    _assertNotHalted($, asset, AssetAction.Deposit);
    if (to == address(0)) revert StdError.ZeroAddress('to');
    if (amount == 0) revert StdError.ZeroAmount();

    IERC20(asset).safeTransferFrom(_msgSender(), address(this), amount);
    $.entrypoint.deposit(asset, to, amount);

    emit Deposited(asset, to, amount);
  }

  function redeem(address asset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertAssetInitialized($, asset);

    IERC20(asset).safeTransfer(to, amount);

    emit Redeemed(asset, to, amount);
  }

  //=========== NOTE: EOL FUNCTIONS ===========//

  function initializeEOL(uint256 eolId, address asset) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertEOLNotInitialized($, eolId);
    _assertAssetInitialized($, asset);

    $.eols[eolId].initialized = true;
    $.eols[eolId].asset = asset;

    emit EOLInitialized(eolId, asset);
  }

  function allocateEOL(uint256 eolId, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertEOLInitialized($, eolId);

    EOLInfo storage eolInfo = $.eols[eolId];

    eolInfo.availableEOL += amount;

    emit EOLAllocated(eolId, amount);
  }

  function deallocateEOL(uint256 eolId, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertEOLInitialized($, eolId);
    _assertOnlyStrategyExecutor($, eolId);

    EOLInfo storage eolInfo = $.eols[eolId];

    eolInfo.availableEOL -= amount;
    $.entrypoint.deallocateEOL(eolId, amount);

    emit EOLDeallocated(eolId, amount);
  }

  function fetchEOL(uint256 eolId, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertEOLInitialized($, eolId);
    _assertOnlyStrategyExecutor($, eolId);
    _assertNotHalted($, eolId, EOLAction.FetchEOL);

    EOLInfo storage eolInfo = $.eols[eolId];

    eolInfo.availableEOL -= amount;
    IERC20(eolInfo.asset).safeTransfer(eolInfo.strategyExecutor, amount);

    emit EOLFetched(eolId, amount);
  }

  function returnEOL(uint256 eolId, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertEOLInitialized($, eolId);
    _assertOnlyStrategyExecutor($, eolId);

    EOLInfo storage eolInfo = $.eols[eolId];

    IERC20(eolInfo.asset).safeTransferFrom(eolInfo.strategyExecutor, address(this), amount);
    eolInfo.availableEOL += amount;

    emit EOLReturned(eolId, amount);
  }

  function settleYield(uint256 eolId, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertEOLInitialized($, eolId);
    _assertOnlyStrategyExecutor($, eolId);

    $.entrypoint.settleYield(eolId, amount);

    emit YieldSettled(eolId, amount);
  }

  function settleLoss(uint256 eolId, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertEOLInitialized($, eolId);
    _assertOnlyStrategyExecutor($, eolId);

    $.entrypoint.settleLoss(eolId, amount);

    emit LossSettled(eolId, amount);
  }

  function settleExtraRewards(uint256 eolId, address reward, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertEOLInitialized($, eolId);
    _assertOnlyStrategyExecutor($, eolId);
    _assertAssetInitialized($, reward);
    if ($.eols[eolId].asset == reward) revert StdError.InvalidAddress('reward');

    IERC20(reward).safeTransferFrom(_msgSender(), address(this), amount);
    $.entrypoint.settleExtraRewards(eolId, reward, amount);

    emit ExtraRewardsSettled(eolId, reward, amount);
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function setEntrypoint(IMitosisVaultEntrypoint entrypoint) external onlyOwner {
    _getStorageV1().entrypoint = entrypoint;
    emit EntrypointSet(address(entrypoint));
  }

  function setStrategyExecutor(uint256 eolId, address strategyExecutor) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    EOLInfo storage eolInfo = $.eols[eolId];

    _assertEOLInitialized($, eolId);

    if (eolInfo.strategyExecutor != address(0)) {
      // NOTE: no way to check if every extra rewards are settled.
      bool drained = IStrategyExecutor(eolInfo.strategyExecutor).totalBalance() == 0
        && IStrategyExecutor(eolInfo.strategyExecutor).lastSettledBalance() == 0;

      if (!drained) revert MitosisVault__StrategyExecutorNotDrained(eolId, eolInfo.strategyExecutor);
    }

    if (eolId != IStrategyExecutor(strategyExecutor).eolId()) {
      revert StdError.InvalidId('strategyExecutor.eolId');
    }
    if (address(this) != address(IStrategyExecutor(strategyExecutor).vault())) {
      revert StdError.InvalidAddress('strategyExecutor.vault');
    }
    if (eolInfo.asset != address(IStrategyExecutor(strategyExecutor).asset())) {
      revert StdError.InvalidAddress('strategyExecutor.asset');
    }

    eolInfo.strategyExecutor = strategyExecutor;
    emit StrategyExecutorSet(eolId, strategyExecutor);
  }

  function halt(address asset, AssetAction action) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    _assertAssetInitialized($, asset);
    return _halt($, asset, action);
  }

  function resume(address asset, AssetAction action) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    _assertAssetInitialized($, asset);
    return _resume($, asset, action);
  }

  function halt(uint256 eolId, EOLAction action) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    _assertEOLInitialized($, eolId);
    return _halt($, eolId, action);
  }

  function resume(uint256 eolId, EOLAction action) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    _assertEOLInitialized($, eolId);
    return _resume($, eolId, action);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _assertOnlyEntrypoint(StorageV1 storage $) internal view {
    if (_msgSender() != address($.entrypoint)) revert StdError.InvalidAddress('entrypoint');
  }

  function _assertOnlyStrategyExecutor(StorageV1 storage $, uint256 eolId) internal view {
    if (_msgSender() != $.eols[eolId].strategyExecutor) revert StdError.InvalidAddress('strategyExecutor');
  }

  function _assertAssetInitialized(StorageV1 storage $, address asset) internal view {
    if (!_isAssetInitialized($, asset)) revert MitosisVault__AssetNotInitialized(asset);
  }

  function _assertAssetNotInitialized(StorageV1 storage $, address asset) internal view {
    if (_isAssetInitialized($, asset)) revert MitosisVault__AssetAlreadyInitialized(asset);
  }

  function _assertEOLInitialized(StorageV1 storage $, uint256 eolId) internal view {
    if (!_isEOLInitialized($, eolId)) revert MitosisVault__EOLNotInitialized(eolId);
  }

  function _assertEOLNotInitialized(StorageV1 storage $, uint256 eolId) internal view {
    if (_isEOLInitialized($, eolId)) revert MitosisVault__EOLAlreadyInitialized(eolId);
  }

  function _assertNotHalted(StorageV1 storage $, address asset, AssetAction action) internal view {
    if (_isHalted($, asset, action)) revert StdError.Halted();
  }

  function _assertNotHalted(StorageV1 storage $, uint256 eolId, EOLAction action) internal view {
    if (_isHalted($, eolId, action)) revert StdError.Halted();
  }

  function _isHalted(StorageV1 storage $, address asset, AssetAction action) internal view returns (bool) {
    return $.assets[asset].isHalted[action];
  }

  function _isHalted(StorageV1 storage $, uint256 eolId, EOLAction action) internal view returns (bool) {
    return $.eols[eolId].isHalted[action];
  }

  function _isAssetInitialized(StorageV1 storage $, address asset) internal view returns (bool) {
    return $.assets[asset].initialized;
  }

  function _isEOLInitialized(StorageV1 storage $, uint256 eolId) internal view returns (bool) {
    return $.eols[eolId].initialized;
  }

  function _halt(StorageV1 storage $, address asset, AssetAction action) internal {
    $.assets[asset].isHalted[action] = true;
    emit Halted(asset, action);
  }

  function _resume(StorageV1 storage $, address asset, AssetAction action) internal {
    $.assets[asset].isHalted[action] = false;
    emit Resumed(asset, action);
  }

  function _halt(StorageV1 storage $, uint256 eolId, EOLAction action) internal {
    $.eols[eolId].isHalted[action] = true;
    emit Halted(eolId, action);
  }

  function _resume(StorageV1 storage $, uint256 eolId, EOLAction action) internal {
    $.eols[eolId].isHalted[action] = false;
    emit Resumed(eolId, action);
  }
}
