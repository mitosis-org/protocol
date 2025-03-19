// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Address } from '@oz-v5/utils/Address.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { MitosisVaultStorageV1 } from '../branch/MitosisVaultStorageV1.sol';
import { AssetAction, MatrixAction, IMitosisVault, IMatrixMitosisVault } from '../interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '../interfaces/branch/IMitosisVaultEntrypoint.sol';
import { IMatrixStrategyExecutor } from '../interfaces/branch/strategy/IMatrixStrategyExecutor.sol';
import { IStrategyExecutor } from '../interfaces/branch/strategy/IStrategyExecutor.sol';
import { Pausable } from '../lib/Pausable.sol';
import { StdError } from '../lib/StdError.sol';

contract MitosisVault is IMitosisVault, Pausable, Ownable2StepUpgradeable, UUPSUpgradeable, MitosisVaultStorageV1 {
  using SafeERC20 for IERC20;
  using Address for address;

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() {
    _disableInitializers();
  }

  fallback() external payable {
    revert StdError.NotSupported();
  }

  receive() external payable {
    revert StdError.NotSupported();
  }

  function initialize(address owner_) public initializer {
    __Pausable_init();
    __Ownable2Step_init();
    __Ownable_init(owner_);
    __UUPSUpgradeable_init();
  }

  //=========== NOTE: VIEW FUNCTIONS ===========//

  function maxCap(address asset) external view returns (uint256) {
    return _getStorageV1().assets[asset].maxCap;
  }

  function availableCap(address asset) external view returns (uint256) {
    return _getStorageV1().assets[asset].availableCap;
  }

  function isAssetActionHalted(address asset, AssetAction action) external view returns (bool) {
    return _isHalted(_getStorageV1(), asset, action);
  }

  function isMatrixActionHalted(address hubMatrixVault, MatrixAction action) external view returns (bool) {
    return _isHalted(_getStorageV1(), hubMatrixVault, action);
  }

  function isAssetInitialized(address asset) external view returns (bool) {
    return _isAssetInitialized(_getStorageV1(), asset);
  }

  function isMatrixInitialized(address hubMatrixVault) external view returns (bool) {
    return _isMatrixInitialized(_getStorageV1(), hubMatrixVault);
  }

  function availableMatrix(address hubMatrixVault) external view returns (uint256) {
    return _getStorageV1().matrices[hubMatrixVault].availableLiquidity;
  }

  function entrypoint() external view returns (address) {
    return address(_getStorageV1().entrypoint);
  }

  function matrixStrategyExecutor(address hubMatrixVault) external view returns (address) {
    return _getStorageV1().matrices[hubMatrixVault].strategyExecutor;
  }

  //=========== NOTE: MUTATIVE FUNCTIONS ===========//

  //=========== NOTE: MUTATIVE - ASSET FUNCTIONS ===========//

  function initializeAsset(address asset) external whenNotPaused {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertAssetNotInitialized($, asset);

    $.assets[asset].initialized = true;
    emit AssetInitialized(asset);

    // NOTE: we halt deposit and keep the cap at zero by default.
    _haltAsset($, asset, AssetAction.Deposit);
  }

  function deposit(address asset, address to, uint256 amount) external whenNotPaused {
    StorageV1 storage $ = _getStorageV1();
    _deposit($, asset, to, amount);

    $.entrypoint.deposit(asset, to, amount);
    emit Deposited(asset, to, amount);
  }

  function depositWithSupplyMatrix(address asset, address to, address hubMatrixVault, uint256 amount)
    external
    whenNotPaused
  {
    StorageV1 storage $ = _getStorageV1();
    _deposit($, asset, to, amount);

    _assertMatrixInitialized($, hubMatrixVault);
    require(asset == $.matrices[hubMatrixVault].asset, IMitosisVault__InvalidMatrixVault(hubMatrixVault, asset));

    $.entrypoint.depositWithSupplyMatrix(asset, to, hubMatrixVault, amount);
    emit MatrixDepositedWithSupply(asset, to, hubMatrixVault, amount);
  }

  function redeem(address asset, address to, uint256 amount) external whenNotPaused {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertAssetInitialized($, asset);

    IERC20(asset).safeTransfer(to, amount);

    emit Redeemed(asset, to, amount);
  }

  //=========== NOTE: MUTATIVE - EOL FUNCTIONS ===========//

  function initializeMatrix(address hubMatrixVault, address asset) external whenNotPaused {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertMatrixNotInitialized($, hubMatrixVault);
    _assertAssetInitialized($, asset);

    $.matrices[hubMatrixVault].initialized = true;
    $.matrices[hubMatrixVault].asset = asset;

    emit MatrixInitialized(hubMatrixVault, asset);
  }

  function allocateMatrix(address hubMatrixVault, uint256 amount) external whenNotPaused {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertMatrixInitialized($, hubMatrixVault);

    MatrixInfo storage matrixInfo = $.matrices[hubMatrixVault];

    matrixInfo.availableLiquidity += amount;

    emit MatrixAllocated(hubMatrixVault, amount);
  }

  function deallocateMatrix(address hubMatrixVault, uint256 amount) external whenNotPaused {
    StorageV1 storage $ = _getStorageV1();

    _assertMatrixInitialized($, hubMatrixVault);
    _assertOnlyStrategyExecutor($, hubMatrixVault);

    MatrixInfo storage matrixInfo = $.matrices[hubMatrixVault];

    matrixInfo.availableLiquidity -= amount;
    $.entrypoint.deallocateMatrix(hubMatrixVault, amount);

    emit MatrixDeallocated(hubMatrixVault, amount);
  }

  function fetchMatrix(address hubMatrixVault, uint256 amount) external whenNotPaused {
    StorageV1 storage $ = _getStorageV1();

    _assertMatrixInitialized($, hubMatrixVault);
    _assertOnlyStrategyExecutor($, hubMatrixVault);
    _assertNotHalted($, hubMatrixVault, MatrixAction.FetchMatrix);

    MatrixInfo storage matrixInfo = $.matrices[hubMatrixVault];

    matrixInfo.availableLiquidity -= amount;
    IERC20(matrixInfo.asset).safeTransfer(matrixInfo.strategyExecutor, amount);

    emit MatrixFetched(hubMatrixVault, amount);
  }

  function returnMatrix(address hubMatrixVault, uint256 amount) external whenNotPaused {
    StorageV1 storage $ = _getStorageV1();

    _assertMatrixInitialized($, hubMatrixVault);
    _assertOnlyStrategyExecutor($, hubMatrixVault);

    MatrixInfo storage matrixInfo = $.matrices[hubMatrixVault];

    IERC20(matrixInfo.asset).safeTransferFrom(matrixInfo.strategyExecutor, address(this), amount);
    matrixInfo.availableLiquidity += amount;

    emit MatrixReturned(hubMatrixVault, amount);
  }

  function settleMatrixYield(address hubMatrixVault, uint256 amount) external whenNotPaused {
    StorageV1 storage $ = _getStorageV1();

    _assertMatrixInitialized($, hubMatrixVault);
    _assertOnlyStrategyExecutor($, hubMatrixVault);

    $.entrypoint.settleMatrixYield(hubMatrixVault, amount);

    emit MatrixYieldSettled(hubMatrixVault, amount);
  }

  function settleMatrixLoss(address hubMatrixVault, uint256 amount) external whenNotPaused {
    StorageV1 storage $ = _getStorageV1();

    _assertMatrixInitialized($, hubMatrixVault);
    _assertOnlyStrategyExecutor($, hubMatrixVault);

    $.entrypoint.settleMatrixLoss(hubMatrixVault, amount);

    emit MatrixLossSettled(hubMatrixVault, amount);
  }

  function settleMatrixExtraRewards(address hubMatrixVault, address reward, uint256 amount) external whenNotPaused {
    StorageV1 storage $ = _getStorageV1();

    _assertMatrixInitialized($, hubMatrixVault);
    _assertOnlyStrategyExecutor($, hubMatrixVault);
    _assertAssetInitialized($, reward);
    require(reward != $.matrices[hubMatrixVault].asset, StdError.InvalidAddress('reward'));

    IERC20(reward).safeTransferFrom(_msgSender(), address(this), amount);
    $.entrypoint.settleMatrixExtraRewards(hubMatrixVault, reward, amount);

    emit MatrixExtraRewardsSettled(hubMatrixVault, reward, amount);
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function _authorizeUpgrade(address) internal override onlyOwner { }

  function _authorizePause(address) internal view override onlyOwner { }

  function setEntrypoint(address entrypoint_) external onlyOwner {
    _getStorageV1().entrypoint = IMitosisVaultEntrypoint(entrypoint_);
    emit EntrypointSet(address(entrypoint_));
  }

  function setMatrixStrategyExecutor(address hubMatrixVault, address strategyExecutor_) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    MatrixInfo storage matrixInfo = $.matrices[hubMatrixVault];

    _assertMatrixInitialized($, hubMatrixVault);

    if (matrixInfo.strategyExecutor != address(0)) {
      // NOTE: no way to check if every extra rewards are settled.
      bool drained = IMatrixStrategyExecutor(matrixInfo.strategyExecutor).totalBalance() == 0
        && IMatrixStrategyExecutor(matrixInfo.strategyExecutor).storedTotalBalance() == 0;
      require(drained, IMitosisVault__StrategyExecutorNotDrained(hubMatrixVault, matrixInfo.strategyExecutor));
    }

    require(
      hubMatrixVault == IMatrixStrategyExecutor(strategyExecutor_).hubMatrixVault(),
      StdError.InvalidId('matrixStrategyExecutor.hubMatrixVault')
    );
    require(
      address(this) == address(IMatrixStrategyExecutor(strategyExecutor_).vault()),
      StdError.InvalidAddress('matrixStrategyExecutor.vault')
    );
    require(
      matrixInfo.asset == address(IMatrixStrategyExecutor(strategyExecutor_).asset()),
      StdError.InvalidAddress('matrixStrategyExecutor.asset')
    );

    matrixInfo.strategyExecutor = strategyExecutor_;
    emit MatrixStrategyExecutorSet(hubMatrixVault, strategyExecutor_);
  }

  function setCap(address asset, uint256 newCap) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    _assertAssetInitialized($, asset);

    _setCap($, asset, newCap);
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

  function haltMatrix(address hubMatrixVault, MatrixAction action) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    _assertMatrixInitialized($, hubMatrixVault);
    return _haltMatrix($, hubMatrixVault, action);
  }

  function resumeMatrix(address hubMatrixVault, MatrixAction action) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    _assertMatrixInitialized($, hubMatrixVault);
    return _resumeMatrix($, hubMatrixVault, action);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _assertOnlyEntrypoint(StorageV1 storage $) internal view {
    require(_msgSender() == address($.entrypoint), StdError.Unauthorized());
  }

  function _assertOnlyStrategyExecutor(StorageV1 storage $, address vault) internal view {
    require(_msgSender() == $.matrices[vault].strategyExecutor, StdError.Unauthorized());
  }

  function _assertCapNotExceeded(StorageV1 storage $, address asset, uint256 amount) internal view {
    uint256 available = $.assets[asset].availableCap;
    require(available >= amount, IMitosisVault__ExceededCap(asset, amount, available));
  }

  function _assertAssetInitialized(StorageV1 storage $, address asset) internal view {
    require(_isAssetInitialized($, asset), IMitosisVault__AssetNotInitialized(asset));
  }

  function _assertAssetNotInitialized(StorageV1 storage $, address asset) internal view {
    require(!_isAssetInitialized($, asset), IMitosisVault__AssetAlreadyInitialized(asset));
  }

  function _assertMatrixInitialized(StorageV1 storage $, address hubMatrixVault) internal view {
    require(
      _isMatrixInitialized($, hubMatrixVault),
      IMatrixMitosisVault.MatrixDepositedWithSupply__MatrixNotInitialized(hubMatrixVault)
    );
  }

  function _assertMatrixNotInitialized(StorageV1 storage $, address hubMatrixVault) internal view {
    require(
      !_isMatrixInitialized($, hubMatrixVault),
      IMatrixMitosisVault.MatrixDepositedWithSupply__MatrixAlreadyInitialized(hubMatrixVault)
    );
  }

  function _assertNotHalted(StorageV1 storage $, address asset, AssetAction action) internal view {
    require(!_isHalted($, asset, action), StdError.Halted());
  }

  function _assertNotHalted(StorageV1 storage $, address hubMatrixVault, MatrixAction action) internal view {
    require(!_isHalted($, hubMatrixVault, action), StdError.Halted());
  }

  function _isHalted(StorageV1 storage $, address asset, AssetAction action) internal view returns (bool) {
    return $.assets[asset].isHalted[action];
  }

  function _isHalted(StorageV1 storage $, address hubMatrixVault, MatrixAction action) internal view returns (bool) {
    return $.matrices[hubMatrixVault].isHalted[action];
  }

  function _isAssetInitialized(StorageV1 storage $, address asset) internal view returns (bool) {
    return $.assets[asset].initialized;
  }

  function _isMatrixInitialized(StorageV1 storage $, address hubMatrixVault) internal view returns (bool) {
    return $.matrices[hubMatrixVault].initialized;
  }

  function _setCap(StorageV1 storage $, address asset, uint256 newCap) internal {
    AssetInfo storage assetInfo = $.assets[asset];
    uint256 prevCap = assetInfo.maxCap;
    assetInfo.maxCap = newCap;
    assetInfo.availableCap = newCap;
    emit CapSet(_msgSender(), asset, prevCap, newCap);
  }

  function _haltAsset(StorageV1 storage $, address asset, AssetAction action) internal {
    $.assets[asset].isHalted[action] = true;
    emit AssetHalted(asset, action);
  }

  function _resumeAsset(StorageV1 storage $, address asset, AssetAction action) internal {
    $.assets[asset].isHalted[action] = false;
    emit AssetResumed(asset, action);
  }

  function _haltMatrix(StorageV1 storage $, address hubMatrixVault, MatrixAction action) internal {
    $.matrices[hubMatrixVault].isHalted[action] = true;
    emit MatrixHalted(hubMatrixVault, action);
  }

  function _resumeMatrix(StorageV1 storage $, address hubMatrixVault, MatrixAction action) internal {
    $.matrices[hubMatrixVault].isHalted[action] = false;
    emit MatrixResumed(hubMatrixVault, action);
  }

  function _deposit(StorageV1 storage $, address asset, address to, uint256 amount) internal {
    require(to != address(0), StdError.ZeroAddress('to'));
    require(amount != 0, StdError.ZeroAmount());

    _assertAssetInitialized($, asset);
    _assertNotHalted($, asset, AssetAction.Deposit);
    _assertCapNotExceeded($, asset, amount);

    $.assets[asset].availableCap -= amount;
    IERC20(asset).safeTransferFrom(_msgSender(), address(this), amount);
  }
}
