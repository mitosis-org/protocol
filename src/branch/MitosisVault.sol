// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Address } from '@oz-v5/utils/Address.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { PausableUpgradeable } from '@ozu-v5/utils/PausableUpgradeable.sol';

import { MitosisVaultStorageV1 } from '../branch/storage/MitosisVaultStorageV1.sol';
import { AssetAction, EOLAction, IMitosisVault } from '../interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '../interfaces/branch/IMitosisVaultEntrypoint.sol';
import { IStrategyExecutor } from '../interfaces/branch/strategy/IStrategyExecutor.sol';
import { StdError } from '../lib/StdError.sol';

// TODO(thai): add some view functions in MitosisVault

contract MitosisVault is IMitosisVault, PausableUpgradeable, Ownable2StepUpgradeable, MitosisVaultStorageV1 {
  using SafeERC20 for IERC20;
  using Address for address;

  //=========== NOTE: EVENT DEFINITIONS ===========//

  event AssetInitialized(address asset);

  event Deposited(address indexed asset, address indexed to, uint256 amount);
  event Redeemed(address indexed asset, address indexed to, uint256 amount);

  event EOLInitialized(address hubEOLVault, address asset);

  event EOLAllocated(address indexed hubEOLVault, uint256 amount);
  event EOLDeallocated(address indexed hubEOLVault, uint256 amount);
  event EOLFetched(address indexed hubEOLVault, uint256 amount);
  event EOLReturned(address indexed hubEOLVault, uint256 amount);

  event YieldSettled(address indexed hubEOLVault, uint256 amount);
  event LossSettled(address indexed hubEOLVault, uint256 amount);
  event ExtraRewardsSettled(address indexed hubEOLVault, address indexed reward, uint256 amount);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error MitosisVault__AssetNotInitialized(address asset);
  error MitosisVault__AssetAlreadyInitialized(address asset);

  error MitosisVault__EOLNotInitialized(address hubEOLVault);
  error MitosisVault__EOLAlreadyInitialized(address hubEOLVault);

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
    _haltAsset($, asset, AssetAction.Deposit);
  }

  function deposit(address asset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertAssetInitialized($, asset);
    _assertNotHalted($, asset, AssetAction.Deposit);
    require(to != address(0), StdError.ZeroAddress('to'));
    require(amount != 0, StdError.ZeroAmount());

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

  function initializeEOL(address hubEOLVault, address asset) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertEOLNotInitialized($, hubEOLVault);
    _assertAssetInitialized($, asset);

    $.eols[hubEOLVault].initialized = true;
    $.eols[hubEOLVault].asset = asset;

    emit EOLInitialized(hubEOLVault, asset);
  }

  function allocateEOL(address hubEOLVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertEOLInitialized($, hubEOLVault);

    EOLInfo storage eolInfo = $.eols[hubEOLVault];

    eolInfo.availableEOL += amount;

    emit EOLAllocated(hubEOLVault, amount);
  }

  function deallocateEOL(address hubEOLVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertEOLInitialized($, hubEOLVault);
    _assertOnlyStrategyExecutor($, hubEOLVault);

    EOLInfo storage eolInfo = $.eols[hubEOLVault];

    eolInfo.availableEOL -= amount;
    $.entrypoint.deallocateEOL(hubEOLVault, amount);

    emit EOLDeallocated(hubEOLVault, amount);
  }

  function fetchEOL(address hubEOLVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertEOLInitialized($, hubEOLVault);
    _assertOnlyStrategyExecutor($, hubEOLVault);
    _assertNotHalted($, hubEOLVault, EOLAction.FetchEOL);

    EOLInfo storage eolInfo = $.eols[hubEOLVault];

    eolInfo.availableEOL -= amount;
    IERC20(eolInfo.asset).safeTransfer(eolInfo.strategyExecutor, amount);

    emit EOLFetched(hubEOLVault, amount);
  }

  function returnEOL(address hubEOLVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertEOLInitialized($, hubEOLVault);
    _assertOnlyStrategyExecutor($, hubEOLVault);

    EOLInfo storage eolInfo = $.eols[hubEOLVault];

    IERC20(eolInfo.asset).safeTransferFrom(eolInfo.strategyExecutor, address(this), amount);
    eolInfo.availableEOL += amount;

    emit EOLReturned(hubEOLVault, amount);
  }

  function settleYield(address hubEOLVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertEOLInitialized($, hubEOLVault);
    _assertOnlyStrategyExecutor($, hubEOLVault);

    $.entrypoint.settleYield(hubEOLVault, amount);

    emit YieldSettled(hubEOLVault, amount);
  }

  function settleLoss(address hubEOLVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertEOLInitialized($, hubEOLVault);
    _assertOnlyStrategyExecutor($, hubEOLVault);

    $.entrypoint.settleLoss(hubEOLVault, amount);

    emit LossSettled(hubEOLVault, amount);
  }

  function settleExtraRewards(address hubEOLVault, address reward, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertEOLInitialized($, hubEOLVault);
    _assertOnlyStrategyExecutor($, hubEOLVault);
    _assertAssetInitialized($, reward);
    require(reward != $.eols[hubEOLVault].asset, StdError.InvalidAddress('reward'));

    IERC20(reward).safeTransferFrom(_msgSender(), address(this), amount);
    $.entrypoint.settleExtraRewards(hubEOLVault, reward, amount);

    emit ExtraRewardsSettled(hubEOLVault, reward, amount);
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function setEntrypoint(IMitosisVaultEntrypoint entrypoint) external onlyOwner {
    _setEntrypoint(entrypoint);
  }

  function setStrategyExecutor(address hubEOLVault, address strategyExecutor) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    _assertEOLInitialized($, hubEOLVault);

    _setStrategyExecutor($, hubEOLVault, strategyExecutor);
  }

  function haltAsset(address asset, AssetAction action) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    _assertAssetInitialized($, asset);
    return _haltAsset($, asset, action);
  }

  function resumeAsset(address asset, AssetAction action) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    _assertAssetInitialized($, asset);
    return _resumeAsset($, asset, action);
  }

  function haltEOL(address hubEOLVault, EOLAction action) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    _assertEOLInitialized($, hubEOLVault);
    return _haltEOL($, hubEOLVault, action);
  }

  function resumeEOL(address hubEOLVault, EOLAction action) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    _assertEOLInitialized($, hubEOLVault);
    return _resumeEOL($, hubEOLVault, action);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _assertOnlyEntrypoint(StorageV1 storage $) internal view {
    require(_msgSender() == address($.entrypoint), StdError.InvalidAddress('entrypoint'));
  }

  function _assertOnlyStrategyExecutor(StorageV1 storage $, address hubEOLVault) internal view {
    require(_msgSender() == $.eols[hubEOLVault].strategyExecutor, StdError.InvalidAddress('strategyExecutor'));
  }

  function _assertAssetInitialized(StorageV1 storage $, address asset) internal view {
    require(_isAssetInitialized($, asset), MitosisVault__AssetNotInitialized(asset));
  }

  function _assertAssetNotInitialized(StorageV1 storage $, address asset) internal view {
    require(!_isAssetInitialized($, asset), MitosisVault__AssetAlreadyInitialized(asset));
  }

  function _assertEOLInitialized(StorageV1 storage $, address hubEOLVault) internal view {
    require(_isEOLInitialized($, hubEOLVault), MitosisVault__EOLNotInitialized(hubEOLVault));
  }

  function _assertEOLNotInitialized(StorageV1 storage $, address hubEOLVault) internal view {
    require(!_isEOLInitialized($, hubEOLVault), MitosisVault__EOLAlreadyInitialized(hubEOLVault));
  }

  function _assertNotHalted(StorageV1 storage $, address asset, AssetAction action) internal view {
    require(!_isHalted($, asset, action), StdError.Halted());
  }

  function _assertNotHalted(StorageV1 storage $, address hubEOLVault, EOLAction action) internal view {
    require(!_isHalted($, hubEOLVault, action), StdError.Halted());
  }

  function _isHalted(StorageV1 storage $, address asset, AssetAction action) internal view returns (bool) {
    return $.assets[asset].isHalted[action];
  }

  function _isHalted(StorageV1 storage $, address hubEOLVault, EOLAction action) internal view returns (bool) {
    return $.eols[hubEOLVault].isHalted[action];
  }

  function _isAssetInitialized(StorageV1 storage $, address asset) internal view returns (bool) {
    return $.assets[asset].initialized;
  }

  function _isEOLInitialized(StorageV1 storage $, address hubEOLVault) internal view returns (bool) {
    return $.eols[hubEOLVault].initialized;
  }
}
