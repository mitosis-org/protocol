// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { Time } from '@oz-v5/utils/types/Time.sol';

import { IAssetManager } from '../../interfaces/hub/core/IAssetManager.sol';
import { IAssetManagerEntrypoint } from '../../interfaces/hub/core/IAssetManagerEntrypoint.sol';
import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { IMatrixVault } from '../../interfaces/hub/matrix/IMatrixVault.sol';
import { ITreasury } from '../../interfaces/hub/reward/ITreasury.sol';
import { Pausable } from '../../lib/Pausable.sol';
import { StdError } from '../../lib/StdError.sol';
import { AssetManagerStorageV1 } from './AssetManagerStorageV1.sol';

contract AssetManager is IAssetManager, Pausable, Ownable2StepUpgradeable, AssetManagerStorageV1 {
  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_, address treasury_) public initializer {
    __Pausable_init();
    __Ownable2Step_init();
    _transferOwnership(owner_);

    _setTreasury(_getStorageV1(), treasury_);
  }

  //=========== NOTE: ASSET FUNCTIONS ===========//

  function deposit(uint256 chainId, address branchAsset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertBranchAssetPairExist($, chainId, branchAsset);

    address hubAsset = _branchAssetState($, chainId, branchAsset).hubAsset;
    _mint($, chainId, hubAsset, to, amount);

    emit Deposited(chainId, hubAsset, to, amount);
  }

  function depositWithSupplyMatrix(
    uint256 chainId,
    address branchAsset,
    address to,
    address matrixVault,
    uint256 amount
  ) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertBranchAssetPairExist($, chainId, branchAsset);
    _assertMatrixInitialized($, chainId, matrixVault);

    address hubAsset = _branchAssetState($, chainId, branchAsset).hubAsset;
    require(hubAsset == IMatrixVault(matrixVault).asset(), IAssetManager__InvalidMatrixVault(matrixVault, hubAsset));

    _mint($, chainId, hubAsset, address(this), amount);

    uint256 maxAssets = IMatrixVault(matrixVault).maxDeposit(to);
    uint256 supplyAmount = amount < maxAssets ? amount : maxAssets;

    IHubAsset(hubAsset).approve(matrixVault, supplyAmount);
    IMatrixVault(matrixVault).deposit(supplyAmount, to);

    // transfer remaining hub assets to `to` because there could be remaining hub assets due to the cap of Matrix Vault.
    if (supplyAmount < amount) {
      IHubAsset(hubAsset).transfer(to, amount - supplyAmount);
    }

    emit DepositedWithSupplyMatrix(chainId, hubAsset, to, matrixVault, amount, supplyAmount);
  }

  function redeem(uint256 chainId, address hubAsset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    require(to != address(0), StdError.ZeroAddress('to'));
    require(amount != 0, StdError.ZeroAmount());

    address branchAsset = _hubAssetState($, hubAsset, chainId).branchAsset;
    _assertBranchAssetPairExist($, chainId, branchAsset);

    _assertHubAssetRedeemable($, hubAsset, chainId);
    _assertCollateralNotInsufficient($, hubAsset, chainId, amount);
    _assertBranchLiquidityNotInsufficient($, hubAsset, chainId, amount);

    _burn($, chainId, hubAsset, _msgSender(), amount);
    $.entrypoint.redeem(chainId, branchAsset, to, amount);

    emit Redeemed(chainId, hubAsset, to, amount);
  }

  //=========== NOTE: MATRIX FUNCTIONS ===========//

  /// @dev only strategist
  function allocateMatrix(uint256 chainId, address matrixVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyStrategist($, matrixVault);
    _assertMatrixInitialized($, chainId, matrixVault);

    uint256 idle = _matrixIdle($, matrixVault);
    require(amount <= idle, IAssetManager__MatrixInsufficient(matrixVault));

    $.entrypoint.allocateMatrix(chainId, matrixVault, amount);

    address hubAsset = IMatrixVault(matrixVault).asset();
    _hubAssetState($, hubAsset, chainId).branchAllocated += amount;
    $.matrixStates[matrixVault].allocation += amount;

    emit MatrixAllocated(chainId, matrixVault, amount);
  }

  /// @dev only entrypoint
  function deallocateMatrix(uint256 chainId, address matrixVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);

    address hubAsset = IMatrixVault(matrixVault).asset();
    _hubAssetState($, hubAsset, chainId).branchAllocated -= amount;
    $.matrixStates[matrixVault].allocation -= amount;

    emit MatrixDeallocated(chainId, matrixVault, amount);
  }

  /// @dev only strategist
  function reserveMatrix(address matrixVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyStrategist($, matrixVault);

    uint256 idle = _matrixIdle($, matrixVault);
    require(amount <= idle, IAssetManager__MatrixInsufficient(matrixVault));

    $.reclaimQueue.sync(matrixVault, amount);
  }

  /// @dev only entrypoint
  function settleMatrixYield(uint256 chainId, address matrixVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);

    // Increase MatrixVault's shares value.
    address asset = IMatrixVault(matrixVault).asset();
    _mint($, chainId, asset, address(matrixVault), amount);

    _hubAssetState($, asset, chainId).branchAllocated += amount;
    $.matrixStates[matrixVault].allocation += amount;

    emit MatrixRewardSettled(chainId, matrixVault, asset, amount);
  }

  /// @dev only entrypoint
  function settleMatrixLoss(uint256 chainId, address matrixVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);

    // Decrease MatrixVault's shares value.
    address asset = IMatrixVault(matrixVault).asset();
    _burn($, chainId, asset, matrixVault, amount);

    _hubAssetState($, asset, chainId).branchAllocated -= amount;
    $.matrixStates[matrixVault].allocation -= amount;

    emit MatrixLossSettled(chainId, matrixVault, asset, amount);
  }

  /// @dev only entrypoint
  function settleMatrixExtraRewards(uint256 chainId, address matrixVault, address branchReward, uint256 amount)
    external
  {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertBranchAssetPairExist($, chainId, branchReward);
    _assertTreasurySet($);

    address hubReward = _branchAssetState($, chainId, branchReward).hubAsset;
    _mint($, chainId, hubReward, address(this), amount);
    emit MatrixRewardSettled(chainId, matrixVault, hubReward, amount);

    IHubAsset(hubReward).approve(address($.treasury), amount);
    $.treasury.storeRewards(matrixVault, hubReward, amount);
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function initializeAsset(uint256 chainId, address hubAsset) external onlyOwner {
    _assertOnlyContract(hubAsset, 'hubAsset');

    StorageV1 storage $ = _getStorageV1();

    address branchAsset = _hubAssetState($, hubAsset, chainId).branchAsset;
    _assertBranchAssetPairExist($, chainId, branchAsset);

    $.entrypoint.initializeAsset(chainId, branchAsset);
    _setHubAssetRedeemStatus(_getStorageV1(), hubAsset, chainId, true);

    emit AssetInitialized(hubAsset, chainId, branchAsset);
  }

  function setHubAssetRedeemStatus(uint256 chainId, address hubAsset, bool available) external onlyOwner {
    _setHubAssetRedeemStatus(_getStorageV1(), hubAsset, chainId, available);
  }

  function setHubAssetLiquidityThresholdRatio(uint256 chainId, address hubAsset, uint256 thresholdRatio)
    external
    onlyOwner
  {
    _setHubAssetLiquidityThresholdRatio(_getStorageV1(), hubAsset, chainId, thresholdRatio);
  }

  function setHubAssetLiquidityThresholdRatio(
    uint256[] calldata chainIds,
    address[] calldata hubAssets,
    uint256[] calldata thresholdRatios
  ) external onlyOwner {
    require(chainIds.length == hubAssets.length, StdError.InvalidParameter('hubAssets'));
    require(chainIds.length == thresholdRatios.length, StdError.InvalidParameter('thresholdRatios'));

    StorageV1 storage $ = _getStorageV1();
    for (uint256 i = 0; i < chainIds.length; i++) {
      _setHubAssetLiquidityThresholdRatio($, hubAssets[i], chainIds[i], thresholdRatios[i]);
    }
  }

  function initializeMatrix(uint256 chainId, address matrixVault) external onlyOwner {
    _assertOnlyContract(matrixVault, 'matrixVault');

    StorageV1 storage $ = _getStorageV1();

    address hubAsset = IMatrixVault(matrixVault).asset();
    address branchAsset = _hubAssetState($, hubAsset, chainId).branchAsset;
    _assertBranchAssetPairExist($, chainId, branchAsset);

    _assertMatrixNotInitialized($, chainId, matrixVault);
    $.matrixInitialized[chainId][matrixVault] = true;

    $.entrypoint.initializeMatrix(chainId, matrixVault, branchAsset);
    emit MatrixInitialized(hubAsset, chainId, matrixVault, branchAsset);
  }

  function setAssetPair(address hubAsset, uint256 branchChainId, address branchAsset) external onlyOwner {
    _assertOnlyContract(address(hubAsset), 'hubAsset');

    // TODO(ray): handle already initialized asset through initializeAsset.
    //
    // https://github.com/mitosis-org/protocol/pull/23#discussion_r1728680943
    StorageV1 storage $ = _getStorageV1();
    _hubAssetState($, hubAsset, branchChainId).branchAsset = branchAsset;
    _branchAssetState($, branchChainId, branchAsset).hubAsset = hubAsset;
    emit AssetPairSet(hubAsset, branchChainId, branchAsset);
  }

  function setEntrypoint(address entrypoint_) external onlyOwner {
    _setEntrypoint(_getStorageV1(), entrypoint_);
  }

  function setReclaimQueue(address reclaimQueue_) external onlyOwner {
    _setReclaimQueue(_getStorageV1(), reclaimQueue_);
  }

  function setTreasury(address treasury_) external onlyOwner {
    _setTreasury(_getStorageV1(), treasury_);
  }

  function setStrategist(address matrixVault, address strategist) external onlyOwner {
    _setStrategist(_getStorageV1(), matrixVault, strategist);
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _mint(StorageV1 storage $, uint256 chainId, address asset, address account, uint256 amount) internal {
    IHubAsset(asset).mint(account, amount);
    _hubAssetState($, asset, chainId).collateral += amount;
  }

  function _burn(StorageV1 storage $, uint256 chainId, address asset, address account, uint256 amount) internal {
    IHubAsset(asset).burn(account, amount);
    _hubAssetState($, asset, chainId).collateral -= amount;
  }

  //=========== NOTE: ASSERTIONS ===========//

  function _assertOnlyContract(address addr, string memory paramName) internal view {
    require(addr.code.length > 0, StdError.InvalidParameter(paramName));
  }
}
