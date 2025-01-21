// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Address } from '@oz-v5/utils/Address.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { MitosisVaultStorageV1 } from '../branch/MitosisVaultStorageV1.sol';
import { AssetAction, MatrixAction, IMitosisVault, IMatrixMitosisVault } from '../interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '../interfaces/branch/IMitosisVaultEntrypoint.sol';
import { IMatrixStrategyExecutor } from '../interfaces/branch/strategy/IMatrixStrategyExecutor.sol';
import { IStrategyExecutor } from '../interfaces/branch/strategy/IStrategyExecutor.sol';
import { Pausable } from '../lib/Pausable.sol';
import { StdError } from '../lib/StdError.sol';

// TODO(thai): add some view functions in MitosisVault

contract MitosisVault is IMitosisVault, Pausable, Ownable2StepUpgradeable, MitosisVaultStorageV1 {
  using SafeERC20 for IERC20;
  using Address for address;

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

  //=========== NOTE: VIEW FUNCTIONS ===========//

  function isAssetActionHalted(address asset, AssetAction action) external view returns (bool) {
    return _isHalted(_getStorageV1(), asset, action);
  }

  function isMatrixActionHalted(address hubMatrixBasketAsset, MatrixAction action) external view returns (bool) {
    return _isHalted(_getStorageV1(), hubMatrixBasketAsset, action);
  }

  function isAssetInitialized(address asset) external view returns (bool) {
    return _isAssetInitialized(_getStorageV1(), asset);
  }

  function isMatrixInitialized(address hubMatrixBasketAsset) external view returns (bool) {
    return _isMatrixInitialized(_getStorageV1(), hubMatrixBasketAsset);
  }

  function availableMatrixLiquidity(address hubMatrixBasketAsset) external view returns (uint256) {
    return _getStorageV1().matrices[hubMatrixBasketAsset].availableLiquidity;
  }

  function entrypoint() external view returns (address) {
    return address(_getStorageV1().entrypoint);
  }

  function matrixStrategyExecutor(address hubMatrixBasketAsset) external view returns (address) {
    return _getStorageV1().matrices[hubMatrixBasketAsset].strategyExecutor;
  }

  //=========== NOTE: MUTATIVE FUNCTIONS ===========//

  //=========== NOTE: MUTATIVE - ASSET FUNCTIONS ===========//

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
    _deposit($, asset, to, amount);

    $.entrypoint.deposit(asset, to, amount);
    emit Deposited(asset, to, amount);
  }

  function depositWithMatrixSupply(address asset, address to, address hubMatrixBasketAsset, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();
    _deposit($, asset, to, amount);

    _assertMatrixInitialized($, hubMatrixBasketAsset);
    require(
      asset == $.matrices[hubMatrixBasketAsset].asset, IMitosisVault__InvalidMatrixVault(hubMatrixBasketAsset, asset)
    );

    $.entrypoint.depositWithMatrixSupply(asset, to, hubMatrixBasketAsset, amount);
    emit MatrixDepositedWithSupply(asset, to, hubMatrixBasketAsset, amount);
  }

  function redeem(address asset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertAssetInitialized($, asset);

    IERC20(asset).safeTransfer(to, amount);

    emit Redeemed(asset, to, amount);
  }

  //=========== NOTE: MUTATIVE - EOL FUNCTIONS ===========//

  function initializeMatrix(address hubMatrixBasketAsset, address asset) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertMatrixNotInitialized($, hubMatrixBasketAsset);
    _assertAssetInitialized($, asset);

    $.matrices[hubMatrixBasketAsset].initialized = true;
    $.matrices[hubMatrixBasketAsset].asset = asset;

    emit MatrixInitialized(hubMatrixBasketAsset, asset);
  }

  function allocateMatrixLiquidity(address hubMatrixBasketAsset, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertMatrixInitialized($, hubMatrixBasketAsset);

    MatrixInfo storage matrixInfo = $.matrices[hubMatrixBasketAsset];

    matrixInfo.availableLiquidity += amount;

    emit MatrixLiquidityAllocated(hubMatrixBasketAsset, amount);
  }

  function deallocateMatrixLiquidity(address hubMatrixBasketAsset, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertMatrixInitialized($, hubMatrixBasketAsset);
    _assertOnlyStrategyExecutor($, hubMatrixBasketAsset);

    MatrixInfo storage matrixInfo = $.matrices[hubMatrixBasketAsset];

    matrixInfo.availableLiquidity -= amount;
    $.entrypoint.deallocateMatrixLiquidity(hubMatrixBasketAsset, amount);

    emit MatrixLiquidityDeallocated(hubMatrixBasketAsset, amount);
  }

  function fetchMatrixLiquidity(address hubMatrixBasketAsset, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertMatrixInitialized($, hubMatrixBasketAsset);
    _assertOnlyStrategyExecutor($, hubMatrixBasketAsset);
    _assertNotHalted($, hubMatrixBasketAsset, MatrixAction.FetchMatrix);

    MatrixInfo storage matrixInfo = $.matrices[hubMatrixBasketAsset];

    matrixInfo.availableLiquidity -= amount;
    IERC20(matrixInfo.asset).safeTransfer(matrixInfo.strategyExecutor, amount);

    emit MatrixLiquidityFetched(hubMatrixBasketAsset, amount);
  }

  function returnMatrixLiquidity(address hubMatrixBasketAsset, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertMatrixInitialized($, hubMatrixBasketAsset);
    _assertOnlyStrategyExecutor($, hubMatrixBasketAsset);

    MatrixInfo storage matrixInfo = $.matrices[hubMatrixBasketAsset];

    IERC20(matrixInfo.asset).safeTransferFrom(matrixInfo.strategyExecutor, address(this), amount);
    matrixInfo.availableLiquidity += amount;

    emit MatrixLiquidityReturned(hubMatrixBasketAsset, amount);
  }

  function settleMatrixYield(address hubMatrixBasketAsset, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertMatrixInitialized($, hubMatrixBasketAsset);
    _assertOnlyStrategyExecutor($, hubMatrixBasketAsset);

    $.entrypoint.settleMatrixYield(hubMatrixBasketAsset, amount);

    emit MatrixYieldSettled(hubMatrixBasketAsset, amount);
  }

  function settleMatrixLoss(address hubMatrixBasketAsset, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertMatrixInitialized($, hubMatrixBasketAsset);
    _assertOnlyStrategyExecutor($, hubMatrixBasketAsset);

    $.entrypoint.settleMatrixLoss(hubMatrixBasketAsset, amount);

    emit MatrixLossSettled(hubMatrixBasketAsset, amount);
  }

  function settleMatrixExtraRewards(address hubMatrixBasketAsset, address reward, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertMatrixInitialized($, hubMatrixBasketAsset);
    _assertOnlyStrategyExecutor($, hubMatrixBasketAsset);
    _assertAssetInitialized($, reward);
    require(reward != $.matrices[hubMatrixBasketAsset].asset, StdError.InvalidAddress('reward'));

    IERC20(reward).safeTransferFrom(_msgSender(), address(this), amount);
    $.entrypoint.settleMatrixExtraRewards(hubMatrixBasketAsset, reward, amount);

    emit MatrixExtraRewardsSettled(hubMatrixBasketAsset, reward, amount);
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function setEntrypoint(address entrypoint_) external onlyOwner {
    _getStorageV1().entrypoint = IMitosisVaultEntrypoint(entrypoint_);
    emit EntrypointSet(address(entrypoint_));
  }

  function setMatrixStrategyExecutor(address hubMatrixBasketAsset, address strategyExecutor_) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    MatrixInfo storage matrixInfo = $.matrices[hubMatrixBasketAsset];

    _assertMatrixInitialized($, hubMatrixBasketAsset);

    if (matrixInfo.strategyExecutor != address(0)) {
      // NOTE: no way to check if every extra rewards are settled.
      bool drained = IMatrixStrategyExecutor(matrixInfo.strategyExecutor).totalBalance() == 0
        && IMatrixStrategyExecutor(matrixInfo.strategyExecutor).storedTotalBalance() == 0;
      require(drained, IMitosisVault__StrategyExecutorNotDrained(hubMatrixBasketAsset, matrixInfo.strategyExecutor));
    }

    require(
      hubMatrixBasketAsset == IMatrixStrategyExecutor(strategyExecutor_).hubMatrixBasketAsset(),
      StdError.InvalidId('matrixStrategyExecutor.hubMatrixBasketAsset')
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
    emit MatrixStrategyExecutorSet(hubMatrixBasketAsset, strategyExecutor_);
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

  function haltMatrix(address hubMatrixBasketAsset, MatrixAction action) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    _assertMatrixInitialized($, hubMatrixBasketAsset);
    return _haltMatrix($, hubMatrixBasketAsset, action);
  }

  function resumeMatrix(address hubMatrixBasketAsset, MatrixAction action) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    _assertMatrixInitialized($, hubMatrixBasketAsset);
    return _resumeMatrix($, hubMatrixBasketAsset, action);
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _assertOnlyEntrypoint(StorageV1 storage $) internal view {
    require(_msgSender() == address($.entrypoint), StdError.Unauthorized());
  }

  function _assertOnlyStrategyExecutor(StorageV1 storage $, address vault) internal view {
    require(_msgSender() == $.matrices[vault].strategyExecutor, StdError.Unauthorized());
  }

  function _assertAssetInitialized(StorageV1 storage $, address asset) internal view {
    require(_isAssetInitialized($, asset), IMitosisVault__AssetNotInitialized(asset));
  }

  function _assertAssetNotInitialized(StorageV1 storage $, address asset) internal view {
    require(!_isAssetInitialized($, asset), IMitosisVault__AssetAlreadyInitialized(asset));
  }

  function _assertMatrixInitialized(StorageV1 storage $, address hubMatrixBasketAsset) internal view {
    require(
      _isMatrixInitialized($, hubMatrixBasketAsset),
      IMatrixMitosisVault.MatrixDepositedWithSupply__MatrixNotInitialized(hubMatrixBasketAsset)
    );
  }

  function _assertMatrixNotInitialized(StorageV1 storage $, address hubMatrixBasketAsset) internal view {
    require(
      !_isMatrixInitialized($, hubMatrixBasketAsset),
      IMatrixMitosisVault.MatrixDepositedWithSupply__MatrixAlreadyInitialized(hubMatrixBasketAsset)
    );
  }

  function _assertNotHalted(StorageV1 storage $, address asset, AssetAction action) internal view {
    require(!_isHalted($, asset, action), StdError.Halted());
  }

  function _assertNotHalted(StorageV1 storage $, address hubMatrixBasketAsset, MatrixAction action) internal view {
    require(!_isHalted($, hubMatrixBasketAsset, action), StdError.Halted());
  }

  function _isHalted(StorageV1 storage $, address asset, AssetAction action) internal view returns (bool) {
    return $.assets[asset].isHalted[action];
  }

  function _isHalted(StorageV1 storage $, address hubMatrixBasketAsset, MatrixAction action)
    internal
    view
    returns (bool)
  {
    return $.matrices[hubMatrixBasketAsset].isHalted[action];
  }

  function _isAssetInitialized(StorageV1 storage $, address asset) internal view returns (bool) {
    return $.assets[asset].initialized;
  }

  function _isMatrixInitialized(StorageV1 storage $, address hubMatrixBasketAsset) internal view returns (bool) {
    return $.matrices[hubMatrixBasketAsset].initialized;
  }

  function _haltAsset(StorageV1 storage $, address asset, AssetAction action) internal {
    $.assets[asset].isHalted[action] = true;
    emit AssetHalted(asset, action);
  }

  function _resumeAsset(StorageV1 storage $, address asset, AssetAction action) internal {
    $.assets[asset].isHalted[action] = false;
    emit AssetResumed(asset, action);
  }

  function _haltMatrix(StorageV1 storage $, address hubMatrixBasketAsset, MatrixAction action) internal {
    $.matrices[hubMatrixBasketAsset].isHalted[action] = true;
    emit MatrixHalted(hubMatrixBasketAsset, action);
  }

  function _resumeMatrix(StorageV1 storage $, address hubMatrixBasketAsset, MatrixAction action) internal {
    $.matrices[hubMatrixBasketAsset].isHalted[action] = false;
    emit MatrixResumed(hubMatrixBasketAsset, action);
  }

  function _deposit(StorageV1 storage $, address asset, address to, uint256 amount) internal {
    _assertAssetInitialized($, asset);
    _assertNotHalted($, asset, AssetAction.Deposit);
    require(to != address(0), StdError.ZeroAddress('to'));
    require(amount != 0, StdError.ZeroAmount());

    IERC20(asset).safeTransferFrom(_msgSender(), address(this), amount);
  }
}
