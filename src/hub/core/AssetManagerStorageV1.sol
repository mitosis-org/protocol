// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { ContextUpgradeable } from '@ozu/utils/ContextUpgradeable.sol';

import { IAssetManagerStorageV1 } from '../../interfaces/hub/core/IAssetManager.sol';
import { IAssetManagerEntrypoint } from '../../interfaces/hub/core/IAssetManagerEntrypoint.sol';
import { IHubAssetFactory } from '../../interfaces/hub/core/IHubAssetFactory.sol';
import { IReclaimQueue } from '../../interfaces/hub/IReclaimQueue.sol';
import { ITreasury } from '../../interfaces/hub/reward/ITreasury.sol';
import { IVLF } from '../../interfaces/hub/vlf/IVLF.sol';
import { IVLFFactory } from '../../interfaces/hub/vlf/IVLFFactory.sol';
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

  struct VLFState {
    address strategist;
    uint256 allocation;
  }

  struct StorageV1 {
    IAssetManagerEntrypoint entrypoint;
    IReclaimQueue reclaimQueue;
    ITreasury treasury;
    IHubAssetFactory hubAssetFactory;
    IVLFFactory vlfFactory;
    // Asset states
    mapping(address hubAsset => mapping(uint256 chainId => HubAssetState)) hubAssetStates;
    mapping(uint256 chainId => mapping(address branchAsset => BranchAssetState)) branchAssetStates;
    // VLF states
    mapping(address vlf => VLFState state) vlfStates;
    mapping(uint256 chainId => mapping(address vlf => bool initialized)) vlfInitialized;
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

  function hubAssetFactory() external view returns (address) {
    return address(_getStorageV1().hubAssetFactory);
  }

  function vlfFactory() external view returns (address) {
    return address(_getStorageV1().vlfFactory);
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

  function vlfInitialized(uint256 chainId, address vlf) external view returns (bool) {
    return _getStorageV1().vlfInitialized[chainId][vlf];
  }

  function vlfIdle(address vlf) external view returns (uint256) {
    return _vlfIdle(_getStorageV1(), vlf);
  }

  function vlfAlloc(address vlf) external view returns (uint256) {
    return _getStorageV1().vlfStates[vlf].allocation;
  }

  function strategist(address vlf) external view returns (address) {
    return _getStorageV1().vlfStates[vlf].strategist;
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

  function _setHubAssetFactory(StorageV1 storage $, address hubAssetFactory_) internal {
    require(hubAssetFactory_.code.length > 0, StdError.InvalidParameter('HubAssetFactory'));

    $.hubAssetFactory = IHubAssetFactory(hubAssetFactory_);

    emit HubAssetFactorySet(hubAssetFactory_);
  }

  function _setVLFFactory(StorageV1 storage $, address vlfFactory_) internal {
    require(vlfFactory_.code.length > 0, StdError.InvalidParameter('VLFFactory'));

    $.vlfFactory = IVLFFactory(vlfFactory_);

    emit VLFFactorySet(vlfFactory_);
  }

  function _setStrategist(StorageV1 storage $, address vlf, address strategist_) internal {
    _assertVLFFactorySet($);
    _assertVLFInstance($, vlf);

    $.vlfStates[vlf].strategist = strategist_;

    emit StrategistSet(vlf, strategist_);
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

  function _vlfIdle(StorageV1 storage $, address vlf) internal view returns (uint256) {
    uint256 total = IVLF(vlf).totalAssets();
    uint256 allocated = $.vlfStates[vlf].allocation;

    return total - allocated;
  }

  // ============================ NOTE: VIRTUAL FUNCTIONS ============================ //

  function _assertOnlyEntrypoint(StorageV1 storage $) internal view virtual {
    require(_msgSender() == address($.entrypoint), StdError.Unauthorized());
  }

  function _assertOnlyStrategist(StorageV1 storage $, address vlf) internal view virtual {
    require(_msgSender() == $.vlfStates[vlf].strategist, StdError.Unauthorized());
  }

  function _assertBranchAssetPairExist(StorageV1 storage $, uint256 chainId, address branchAsset_)
    internal
    view
    virtual
  {
    require(
      _branchAssetState($, chainId, branchAsset_).hubAsset != address(0),
      IAssetManagerStorageV1__BranchAssetPairNotExist(chainId, branchAsset_)
    );
  }

  function _assertTreasurySet(StorageV1 storage $) internal view virtual {
    require(address($.treasury) != address(0), IAssetManagerStorageV1__TreasuryNotSet());
  }

  function _assertBranchLiquidityThresholdSatisfied(
    StorageV1 storage $,
    address hubAsset_,
    uint256 chainId,
    uint256 withdrawAmount
  ) internal view virtual {
    HubAssetState storage hubAssetState = _hubAssetState($, hubAsset_, chainId);
    require(
      hubAssetState.branchLiquidity - withdrawAmount >= hubAssetState.branchLiquidityThreshold,
      IAssetManagerStorageV1__BranchLiquidityThresholdNotSatisfied(
        chainId, hubAsset_, hubAssetState.branchLiquidityThreshold, withdrawAmount
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

  function _assertHubAssetFactorySet(StorageV1 storage $) internal view virtual {
    require(address($.hubAssetFactory) != address(0), IAssetManagerStorageV1__HubAssetFactoryNotSet());
  }

  function _assertHubAssetInstance(StorageV1 storage $, address hubAsset_) internal view virtual {
    require($.hubAssetFactory.isInstance(hubAsset_), IAssetManagerStorageV1__InvalidHubAsset(hubAsset_));
  }

  function _assertVLFFactorySet(StorageV1 storage $) internal view virtual {
    require(address($.vlfFactory) != address(0), IAssetManagerStorageV1__VLFFactoryNotSet());
  }

  function _assertVLFInstance(StorageV1 storage $, address vlf_) internal view virtual {
    require($.vlfFactory.isInstance(vlf_), IAssetManagerStorageV1__InvalidVLF(vlf_));
  }

  function _assertVLFInitialized(StorageV1 storage $, uint256 chainId, address vlf_) internal view virtual {
    bool initialized = $.vlfInitialized[chainId][vlf_];
    require(initialized, IAssetManagerStorageV1__VLFNotInitialized(chainId, vlf_));
  }

  function _assertVLFNotInitialized(StorageV1 storage $, uint256 chainId, address vlf_) internal view virtual {
    bool initialized = $.vlfInitialized[chainId][vlf_];
    require(!initialized, IAssetManagerStorageV1__VLFAlreadyInitialized(chainId, vlf_));
  }
}
