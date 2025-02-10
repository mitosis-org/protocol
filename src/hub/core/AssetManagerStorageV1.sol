// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

import { IAssetManagerStorageV1 } from '../../interfaces/hub/core/IAssetManager.sol';
import { IAssetManagerEntrypoint } from '../../interfaces/hub/core/IAssetManagerEntrypoint.sol';
import { IMatrixVault } from '../../interfaces/hub/matrix/IMatrixVault.sol';
import { IReclaimQueue } from '../../interfaces/hub/matrix/IReclaimQueue.sol';
import { ITreasury } from '../../interfaces/hub/reward/ITreasury.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

abstract contract AssetManagerStorageV1 is IAssetManagerStorageV1, ContextUpgradeable {
  using ERC7201Utils for string;

  struct HubAssetState {
    address branchAsset;
    uint256 branchLiquidity;
    uint256 branchAllocated;
    uint256 branchLiquidityThreshold;
  }

  struct BranchAssetState {
    address hubAsset;
  }

  struct MatrixState {
    address strategist;
    uint256 allocation;
  }

  struct StorageV1 {
    IAssetManagerEntrypoint entrypoint;
    IReclaimQueue reclaimQueue;
    ITreasury treasury;
    // Asset states
    mapping(address hubAsset => mapping(uint256 chainId => HubAssetState)) hubAssetStates;
    mapping(uint256 chainId => mapping(address branchAsset => BranchAssetState)) branchAssetStates;
    // Matrix states
    mapping(address matrixVault => MatrixState state) matrixStates;
    mapping(uint256 chainId => mapping(address matrixVault => bool initialized)) matrixInitialized;
  }

  string private constant _NAMESPACE = 'mitosis.storage.AssetManagerStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function entrypoint() external view returns (address) {
    return address(_getStorageV1().entrypoint);
  }

  function reclaimQueue() external view returns (address) {
    return address(_getStorageV1().reclaimQueue);
  }

  function treasury() external view returns (address) {
    return address(_getStorageV1().treasury);
  }

  function branchAsset(address hubAsset_, uint256 chainId) external view returns (address) {
    return _hubAssetState(_getStorageV1(), hubAsset_, chainId).branchAsset;
  }

  function branchLiquidity(address hubAsset_, uint256 chainId) external view returns (uint256) {
    return _hubAssetState(_getStorageV1(), hubAsset_, chainId).branchLiquidity;
  }

  function branchAllocated(address hubAsset_, uint256 chainId) external view returns (uint256) {
    return _hubAssetState(_getStorageV1(), hubAsset_, chainId).branchAllocated;
  }

  function branchLiquidityThreshold(address hubAsset_, uint256 chainId) external view returns (uint256) {
    return _hubAssetState(_getStorageV1(), hubAsset_, chainId).branchLiquidityThreshold;
  }

  function branchAvailableLiquidity(address hubAsset_, uint256 chainId) external view returns (uint256) {
    return _branchAvailableLiquidity(_getStorageV1(), hubAsset_, chainId);
  }

  function hubAsset(uint256 chainId, address branchAsset_) external view returns (address) {
    return _branchAssetState(_getStorageV1(), chainId, branchAsset_).hubAsset;
  }

  function matrixInitialized(uint256 chainId, address matrixVault) external view returns (bool) {
    return _getStorageV1().matrixInitialized[chainId][matrixVault];
  }

  function matrixIdle(address matrixVault) external view returns (uint256) {
    return _matrixIdle(_getStorageV1(), matrixVault);
  }

  function matrixAlloc(address matrixVault) external view returns (uint256) {
    return _getStorageV1().matrixStates[matrixVault].allocation;
  }

  function strategist(address matrixVault) external view returns (address) {
    return _getStorageV1().matrixStates[matrixVault].strategist;
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  function _setEntrypoint(StorageV1 storage $, address entrypoint_) internal {
    require(entrypoint_.code.length > 0, StdError.InvalidParameter('Entrypoint'));

    $.entrypoint = IAssetManagerEntrypoint(entrypoint_);

    emit EntrypointSet(entrypoint_);
  }

  function _setReclaimQueue(StorageV1 storage $, address reclaimQueue_) internal {
    require(reclaimQueue_.code.length > 0, StdError.InvalidParameter('ReclaimQueue'));

    $.reclaimQueue = IReclaimQueue(reclaimQueue_);

    emit ReclaimQueueSet(reclaimQueue_);
  }

  function _setTreasury(StorageV1 storage $, address treasury_) internal {
    require(treasury_.code.length > 0, StdError.InvalidParameter('Treasury'));

    $.treasury = ITreasury(treasury_);

    emit TreasurySet(treasury_);
  }

  function _setStrategist(StorageV1 storage $, address matrixVault, address strategist_) internal {
    require(matrixVault.code.length > 0, StdError.InvalidParameter('MatrixVault'));

    $.matrixStates[matrixVault].strategist = strategist_;

    emit StrategistSet(matrixVault, strategist_);
  }

  function _setBranchLiquidityThreshold(StorageV1 storage $, address hubAsset_, uint256 chainId, uint256 threshold)
    internal
  {
    HubAssetState storage hubAssetState = _hubAssetState($, hubAsset_, chainId);

    require(hubAssetState.branchAsset != address(0), IAssetManagerStorageV1__HubAssetPairNotExist(hubAsset_));

    hubAssetState.branchLiquidityThreshold = threshold;
    emit BranchLiquidityThresholdSet(hubAsset_, chainId, threshold);
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _hubAssetState(StorageV1 storage $, address hubAsset_, uint256 chainId)
    internal
    view
    returns (HubAssetState storage)
  {
    return $.hubAssetStates[hubAsset_][chainId];
  }

  function _branchAssetState(StorageV1 storage $, uint256 chainId, address branchAsset_)
    internal
    view
    returns (BranchAssetState storage)
  {
    return $.branchAssetStates[chainId][branchAsset_];
  }

  function _branchAvailableLiquidity(StorageV1 storage $, address hubAsset_, uint256 chainId)
    internal
    view
    returns (uint256)
  {
    HubAssetState storage hubAssetState = _hubAssetState($, hubAsset_, chainId);
    return hubAssetState.branchLiquidity - hubAssetState.branchAllocated;
  }

  function _matrixIdle(StorageV1 storage $, address matrixVault) internal view returns (uint256) {
    uint256 total = IMatrixVault(matrixVault).totalAssets();
    uint256 allocated = $.matrixStates[matrixVault].allocation;

    return total - allocated;
  }

  // ============================ NOTE: VIRTUAL FUNCTIONS ============================ //

  function _assertOnlyEntrypoint(StorageV1 storage $) internal view virtual {
    require(_msgSender() == address($.entrypoint), StdError.Unauthorized());
  }

  function _assertOnlyStrategist(StorageV1 storage $, address matrixVault) internal view virtual {
    require(_msgSender() == $.matrixStates[matrixVault].strategist, StdError.Unauthorized());
  }

  function _assertBranchAssetPairExist(StorageV1 storage $, uint256 chainId, address branchAsset_)
    internal
    view
    virtual
  {
    require(
      _branchAssetState($, chainId, branchAsset_).hubAsset != address(0),
      IAssetManagerStorageV1__BranchAssetPairNotExist(branchAsset_)
    );
  }

  function _assertTreasurySet(StorageV1 storage $) internal view virtual {
    require(address($.treasury) != address(0), IAssetManagerStorageV1__TreasuryNotSet());
  }

  function _assertBranchLiquidityThresholdSatisfied(
    StorageV1 storage $,
    address hubAsset_,
    uint256 chainId,
    uint256 redeemAmount
  ) internal view virtual {
    HubAssetState storage hubAssetState = _hubAssetState($, hubAsset_, chainId);
    require(
      hubAssetState.branchLiquidity - redeemAmount >= hubAssetState.branchLiquidityThreshold,
      IAssetManagerStorageV1__BranchLiquidityThresholdNotSatisfied(
        chainId, hubAsset_, hubAssetState.branchLiquidityThreshold, redeemAmount
      )
    );
  }

  function _assertBranchAvailableLiquiditySufficient(
    StorageV1 storage $,
    address hubAsset_,
    uint256 chainId,
    uint256 amount
  ) internal view virtual {
    uint256 available = _branchAvailableLiquidity($, hubAsset_, chainId);
    require(
      amount <= available,
      IAssetManagerStorageV1__BranchAvailableLiquidityInsufficient(chainId, hubAsset_, available, amount)
    );
  }

  function _assertMatrixInitialized(StorageV1 storage $, uint256 chainId, address matrixVault) internal view virtual {
    require(
      $.matrixInitialized[chainId][matrixVault], IAssetManagerStorageV1__MatrixNotInitialized(chainId, matrixVault)
    );
  }

  function _assertMatrixNotInitialized(StorageV1 storage $, uint256 chainId, address matrixVault) internal view virtual {
    require(
      !$.matrixInitialized[chainId][matrixVault], IAssetManagerStorageV1__MatrixAlreadyInitialized(chainId, matrixVault)
    );
  }
}
