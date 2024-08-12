// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Address } from '@oz-v5/utils/Address.sol';
import { PausableUpgradeable } from '@ozu-v5/utils/PausableUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { MitosisVaultStorageV1 } from '@src/branch/storage/MitosisVaultStorageV1.sol';
import { Action, IMitosisVault } from '@src/interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '@src/interfaces/branch/IMitosisVaultEntrypoint.sol';
import { Error } from '@src/lib/Error.sol';

// TODO(thai): add some view functions for MitosisVault

contract MitosisVault is IMitosisVault, PausableUpgradeable, Ownable2StepUpgradeable, MitosisVaultStorageV1 {
  using SafeERC20 for IERC20;
  using Address for address;

  //=========== NOTE: EVENT DEFINITIONS ===========//

  event AssetInitialized(address indexed asset);

  event Deposited(address indexed asset, address indexed to, uint256 amount);
  event Redeemed(address indexed asset, address indexed to, uint256 amount);

  event EOLAllocated(address indexed asset, uint256 amount);
  event EOLDeallocated(address indexed asset, uint256 amount);
  event EOLFetched(address indexed asset, uint256 amount);
  event EOLReturned(address indexed asset, uint256 amount);

  event YieldSettled(address indexed asset, uint256 amount);
  event LossSettled(address indexed asset, uint256 amount);
  event ExtraRewardsSettled(address indexed asset, address indexed reward, uint256 amount);

  event EntrypointSet(address entrypoint);

  event Halted(address indexed asset, Action action);
  event Resumed(address indexed asset, Action action);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error MitosisVault__AssetNotInitialized(address asset);
  error MitosisVault__AssetAlreadyInitialized(address asset);

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() initializer { }

  fallback() external payable {
    revert Error.Unauthorized();
  }

  receive() external payable {
    revert Error.Unauthorized();
  }

  function initialize(address owner_) public initializer {
    __Pausable_init();
    __Ownable2Step_init();
    _transferOwnership(owner_);
  }

  //=========== NOTE: MUTATION FUNCTIONS ===========//

  function initializeAsset(address asset, bool enableDeposit) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertAssetNotInitialized($, asset);

    $.assets[asset].initialized = true;
    emit AssetInitialized(asset);

    if (!enableDeposit) {
      _halt($, asset, Action.Deposit);
    }
  }

  function deposit(address asset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertAssetInitialized($, asset);
    _assertNotHalted($, asset, Action.Deposit);

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

  function allocateEOL(address asset, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertAssetInitialized($, asset);

    AssetInfo storage assetInfo = $.assets[asset];

    assetInfo.availableEOL += amount;

    emit EOLAllocated(asset, amount);
  }

  function deallocateEOL(address asset, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyStrategyExecutor($, asset);
    _assertAssetInitialized($, asset);

    AssetInfo storage assetInfo = $.assets[asset];

    assetInfo.availableEOL -= amount;
    $.entrypoint.deallocateEOL(asset, amount);

    emit EOLDeallocated(asset, amount);
  }

  function fetchEOL(address asset, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyStrategyExecutor($, asset);
    _assertAssetInitialized($, asset);
    _assertNotHalted($, asset, Action.FetchEOL);

    AssetInfo storage assetInfo = $.assets[asset];

    assetInfo.availableEOL -= amount;
    IERC20(asset).safeTransfer(assetInfo.strategyExecutor, amount);

    emit EOLFetched(asset, amount);
  }

  function returnEOL(address asset, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyStrategyExecutor($, asset);
    _assertAssetInitialized($, asset);

    AssetInfo storage assetInfo = $.assets[asset];

    IERC20(asset).safeTransferFrom(assetInfo.strategyExecutor, address(this), amount);
    assetInfo.availableEOL += amount;

    emit EOLReturned(asset, amount);
  }

  function settleYield(address asset, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyStrategyExecutor($, asset);
    _assertAssetInitialized($, asset);

    $.entrypoint.settleYield(asset, amount);

    emit YieldSettled(asset, amount);
  }

  function settleLoss(address asset, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyStrategyExecutor($, asset);
    _assertAssetInitialized($, asset);

    $.entrypoint.settleLoss(asset, amount);

    emit LossSettled(asset, amount);
  }

  function settleExtraRewards(address asset, address reward, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyStrategyExecutor($, asset);
    _assertAssetInitialized($, asset);
    _assertAssetInitialized($, reward);
    if (asset == reward) revert Error.InvalidAddress('reward');

    IERC20(reward).safeTransferFrom(_msgSender(), address(this), amount);
    $.entrypoint.settleExtraRewards(asset, reward, amount);

    emit ExtraRewardsSettled(asset, reward, amount);
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function setEntrypoint(IMitosisVaultEntrypoint entrypoint) external onlyOwner {
    _getStorageV1().entrypoint = entrypoint;
    emit EntrypointSet(address(entrypoint));
  }

  function halt(address asset, Action action) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    _assertAssetInitialized($, asset);
    return _halt($, asset, action);
  }

  function resume(address asset, Action action) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    _assertAssetInitialized($, asset);
    return _resume($, asset, action);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _assertOnlyEntrypoint(StorageV1 storage $) internal view {
    if (_msgSender() != address($.entrypoint)) revert Error.InvalidAddress('entrypoint');
  }

  function _assertOnlyStrategyExecutor(StorageV1 storage $, address asset) internal view {
    if (_msgSender() != $.assets[asset].strategyExecutor) revert Error.InvalidAddress('strategyExecutor');
  }

  function _assertAssetInitialized(StorageV1 storage $, address asset) internal view {
    if (!_isAssetInitialized($, asset)) revert MitosisVault__AssetNotInitialized(asset);
  }

  function _assertAssetNotInitialized(StorageV1 storage $, address asset) internal view {
    if (_isAssetInitialized($, asset)) revert MitosisVault__AssetAlreadyInitialized(asset);
  }

  function _assertNotHalted(StorageV1 storage $, address asset, Action action) internal view {
    if (_isHalted($, asset, action)) revert Error.Halted();
  }

  function _isHalted(StorageV1 storage $, address asset, Action action) internal view returns (bool) {
    return $.assets[asset].isHalted[action];
  }

  function _isAssetInitialized(StorageV1 storage $, address asset) internal view returns (bool) {
    return $.assets[asset].initialized;
  }

  function _halt(StorageV1 storage $, address asset, Action action) internal {
    $.assets[asset].isHalted[action] = true;
    emit Halted(asset, action);
  }

  function _resume(StorageV1 storage $, address asset, Action action) internal {
    $.assets[asset].isHalted[action] = false;
    emit Resumed(asset, action);
  }
}
