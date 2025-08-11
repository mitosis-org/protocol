// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { Time } from '@oz/utils/types/Time.sol';
import { AccessControlEnumerableUpgradeable } from '@ozu/access/extensions/AccessControlEnumerableUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu/proxy/utils/UUPSUpgradeable.sol';

import { IAssetManager } from '../../interfaces/hub/core/IAssetManager.sol';
import { IAssetManagerEntrypoint } from '../../interfaces/hub/core/IAssetManagerEntrypoint.sol';
import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { ITreasury } from '../../interfaces/hub/reward/ITreasury.sol';
import { IVLF } from '../../interfaces/hub/vlf/IVLF.sol';
import { IVLFFactory } from '../../interfaces/hub/vlf/IVLFFactory.sol';
import { Pausable } from '../../lib/Pausable.sol';
import { StdError } from '../../lib/StdError.sol';
import { Versioned } from '../../lib/Versioned.sol';
import { AssetManagerStorageV1 } from './AssetManagerStorageV1.sol';

contract AssetManager is
  IAssetManager,
  Pausable,
  AccessControlEnumerableUpgradeable,
  UUPSUpgradeable,
  AssetManagerStorageV1,
  Versioned
{
  // ============================ NOTE: ROLE DEFINITIONS ============================ //

  /// @dev Role for managing liquidity thresholds and caps
  bytes32 public constant LIQUIDITY_MANAGER_ROLE = keccak256('LIQUIDITY_MANAGER_ROLE');

  modifier onlyOwner() {
    _checkRole(DEFAULT_ADMIN_ROLE);
    _;
  }

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_, address treasury_) public initializer {
    __Pausable_init();
    __AccessControl_init();
    __AccessControlEnumerable_init();
    __UUPSUpgradeable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, owner_);

    _setTreasury(_getStorageV1(), treasury_);
  }

  //=========== NOTE: VIEW FUNCTIONS ===========//

  function isOwner(address account) external view returns (bool) {
    return hasRole(DEFAULT_ADMIN_ROLE, account);
  }

  function isLiquidityManager(address account) external view returns (bool) {
    return hasRole(LIQUIDITY_MANAGER_ROLE, account);
  }

  //=========== NOTE: QUOTE FUNCTIONS ===========//

  function quoteInitializeAsset(uint256 chainId, address branchAsset) external view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    return $.entrypoint.quoteInitializeAsset(chainId, branchAsset);
  }

  function quoteInitializeVLF(uint256 chainId, address vlf, address branchAsset) external view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    return $.entrypoint.quoteInitializeVLF(chainId, vlf, branchAsset);
  }

  function quoteWithdraw(uint256 chainId, address branchAsset, address to, uint256 amount)
    external
    view
    returns (uint256)
  {
    StorageV1 storage $ = _getStorageV1();
    return $.entrypoint.quoteWithdraw(chainId, branchAsset, to, amount);
  }

  function quoteAllocateVLF(uint256 chainId, address vlf, uint256 amount) external view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    return $.entrypoint.quoteAllocateVLF(chainId, vlf, amount);
  }

  //=========== NOTE: ASSET FUNCTIONS ===========//

  function deposit(uint256 chainId, address branchAsset, address to, uint256 amount) external whenNotPaused {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertBranchAssetPairExist($, chainId, branchAsset);

    address hubAsset = _branchAssetState($, chainId, branchAsset).hubAsset;
    _mint($, chainId, hubAsset, to, amount);

    emit Deposited(chainId, hubAsset, to, amount);
  }

  function depositWithSupplyVLF(uint256 chainId, address branchAsset, address to, address vlf, uint256 amount)
    external
    whenNotPaused
  {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertBranchAssetPairExist($, chainId, branchAsset);
    _assertVLFInitialized($, chainId, vlf);

    // NOTE: We don't need to check if the vlf is registered instance of VLFFactory

    address hubAsset = _branchAssetState($, chainId, branchAsset).hubAsset;
    uint256 supplyAmount = 0;

    if (hubAsset != IVLF(vlf).asset()) {
      // just transfer hubAsset if it's not the same as the VLF's asset
      _mint($, chainId, hubAsset, to, amount);
    } else {
      _mint($, chainId, hubAsset, address(this), amount);

      uint256 maxAssets = IVLF(vlf).maxDepositFromChainId(to, chainId);
      supplyAmount = amount < maxAssets ? amount : maxAssets;

      IHubAsset(hubAsset).approve(vlf, supplyAmount);
      IVLF(vlf).depositFromChainId(supplyAmount, to, chainId);

      // transfer remaining hub assets to `to` because there could be remaining hub assets due to the cap of VLF Vault.
      if (supplyAmount < amount) IHubAsset(hubAsset).transfer(to, amount - supplyAmount);
    }

    emit DepositedWithSupplyVLF(chainId, hubAsset, to, vlf, amount, supplyAmount);
  }

  function withdraw(uint256 chainId, address hubAsset, address to, uint256 amount) external payable whenNotPaused {
    StorageV1 storage $ = _getStorageV1();

    require(to != address(0), StdError.ZeroAddress('to'));
    require(amount != 0, StdError.ZeroAmount());

    address branchAsset = _hubAssetState($, hubAsset, chainId).branchAsset;
    _assertBranchAssetPairExist($, chainId, branchAsset);

    _assertBranchAvailableLiquiditySufficient($, hubAsset, chainId, amount);
    _assertBranchLiquidityThresholdSatisfied($, hubAsset, chainId, amount);

    _burn($, chainId, hubAsset, _msgSender(), amount);
    $.entrypoint.withdraw{ value: msg.value }(chainId, branchAsset, to, amount);

    emit Withdrawn(chainId, hubAsset, to, amount);
  }

  //=========== NOTE: VLF FUNCTIONS ===========//

  /// @dev only strategist
  function allocateVLF(uint256 chainId, address vlf, uint256 amount) external payable whenNotPaused {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyStrategist($, vlf);
    _assertVLFInitialized($, chainId, vlf);

    uint256 idle = _vlfIdle($, vlf);
    require(amount <= idle, IAssetManager__VLFInsufficient(vlf));

    $.entrypoint.allocateVLF{ value: msg.value }(chainId, vlf, amount);

    address hubAsset = IVLF(vlf).asset();
    _assertBranchAvailableLiquiditySufficient($, hubAsset, chainId, amount);
    _hubAssetState($, hubAsset, chainId).branchAllocated += amount;
    $.vlfStates[vlf].allocation += amount;

    emit VLFAllocated(_msgSender(), chainId, vlf, amount);
  }

  /// @dev only entrypoint
  function deallocateVLF(uint256 chainId, address vlf, uint256 amount) external whenNotPaused {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);

    address hubAsset = IVLF(vlf).asset();
    _hubAssetState($, hubAsset, chainId).branchAllocated -= amount;
    $.vlfStates[vlf].allocation -= amount;

    emit VLFDeallocated(chainId, vlf, amount);
  }

  /// @dev only strategist
  function reserveVLF(address vlf, uint256 claimCount) external whenNotPaused {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyStrategist($, vlf);

    uint256 idle = _vlfIdle($, vlf);
    (, uint256 simulatedTotalReservedAssets) = $.reclaimQueue.previewSync(vlf, claimCount);
    require(simulatedTotalReservedAssets > 0, IAssetManager__NothingToReserve(vlf));
    require(simulatedTotalReservedAssets <= idle, IAssetManager__VLFInsufficient(vlf));

    (uint256 totalReservedShares, uint256 totalReservedAssets) = $.reclaimQueue.sync(_msgSender(), vlf, claimCount);

    emit VLFReserved(_msgSender(), vlf, claimCount, totalReservedShares, totalReservedAssets);
  }

  /// @dev only entrypoint
  function settleVLFYield(uint256 chainId, address vlf, uint256 amount) external whenNotPaused {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);

    // Increase VLF's shares value.
    address asset = IVLF(vlf).asset();
    _mint($, chainId, asset, address(vlf), amount);

    _hubAssetState($, asset, chainId).branchAllocated += amount;
    $.vlfStates[vlf].allocation += amount;

    emit VLFRewardSettled(chainId, vlf, asset, amount);
  }

  /// @dev only entrypoint
  function settleVLFLoss(uint256 chainId, address vlf, uint256 amount) external whenNotPaused {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);

    // Decrease VLF's shares value.
    address asset = IVLF(vlf).asset();
    _burn($, chainId, asset, vlf, amount);

    _hubAssetState($, asset, chainId).branchAllocated -= amount;
    $.vlfStates[vlf].allocation -= amount;

    emit VLFLossSettled(chainId, vlf, asset, amount);
  }

  /// @dev only entrypoint
  function settleVLFExtraRewards(uint256 chainId, address vlf, address branchReward, uint256 amount)
    external
    whenNotPaused
  {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertBranchAssetPairExist($, chainId, branchReward);
    _assertTreasurySet($);

    address hubReward = _branchAssetState($, chainId, branchReward).hubAsset;
    _mint($, chainId, hubReward, address(this), amount);
    emit VLFRewardSettled(chainId, vlf, hubReward, amount);

    IHubAsset(hubReward).approve(address($.treasury), amount);
    $.treasury.storeRewards(vlf, hubReward, amount);
  }

  function setBranchLiquidityThreshold(uint256 chainId, address hubAsset, uint256 threshold)
    external
    onlyRole(LIQUIDITY_MANAGER_ROLE)
  {
    _setBranchLiquidityThreshold(_getStorageV1(), hubAsset, chainId, threshold);
  }

  function setBranchLiquidityThreshold(
    uint256[] calldata chainIds,
    address[] calldata hubAssets,
    uint256[] calldata thresholds
  ) external onlyRole(LIQUIDITY_MANAGER_ROLE) {
    require(chainIds.length == hubAssets.length, StdError.InvalidParameter('hubAssets'));
    require(chainIds.length == thresholds.length, StdError.InvalidParameter('thresholds'));

    StorageV1 storage $ = _getStorageV1();
    for (uint256 i = 0; i < chainIds.length; i++) {
      _setBranchLiquidityThreshold($, hubAssets[i], chainIds[i], thresholds[i]);
    }
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function _authorizeUpgrade(address) internal override onlyOwner { }

  function _authorizePause(address) internal view override onlyOwner { }

  function initializeAsset(uint256 chainId, address hubAsset) external payable onlyOwner whenNotPaused {
    _assertOnlyContract(hubAsset, 'hubAsset');

    StorageV1 storage $ = _getStorageV1();

    address branchAsset = _hubAssetState($, hubAsset, chainId).branchAsset;
    _assertBranchAssetPairExist($, chainId, branchAsset);

    $.entrypoint.initializeAsset{ value: msg.value }(chainId, branchAsset);
    emit AssetInitialized(hubAsset, chainId, branchAsset);
  }

  function initializeVLF(uint256 chainId, address vlf) external payable onlyOwner whenNotPaused {
    StorageV1 storage $ = _getStorageV1();
    _assertVLFFactorySet($);
    _assertVLFInstance($, vlf);

    address hubAsset = IVLF(vlf).asset();
    address branchAsset = _hubAssetState($, hubAsset, chainId).branchAsset;
    _assertBranchAssetPairExist($, chainId, branchAsset);

    _assertVLFNotInitialized($, chainId, vlf);
    $.vlfInitialized[chainId][vlf] = true;

    $.entrypoint.initializeVLF{ value: msg.value }(chainId, vlf, branchAsset);
    emit VLFInitialized(hubAsset, chainId, vlf, branchAsset);
  }

  function setAssetPair(address hubAsset, uint256 branchChainId, address branchAsset) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    _assertHubAssetFactorySet($);
    _assertHubAssetInstance($, hubAsset);
    _assertBranchAssetPairNotExist($, branchChainId, branchAsset);

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

  function setHubAssetFactory(address hubAssetFactory_) external onlyOwner {
    _setHubAssetFactory(_getStorageV1(), hubAssetFactory_);
  }

  function setVLFFactory(address vlfFactory_) external onlyOwner {
    _setVLFFactory(_getStorageV1(), vlfFactory_);
  }

  function setStrategist(address vlf, address strategist) external onlyOwner {
    _setStrategist(_getStorageV1(), vlf, strategist);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _mint(StorageV1 storage $, uint256 chainId, address asset, address account, uint256 amount) internal {
    IHubAsset(asset).mint(account, amount);
    _hubAssetState($, asset, chainId).branchLiquidity += amount;
  }

  function _burn(StorageV1 storage $, uint256 chainId, address asset, address account, uint256 amount) internal {
    IHubAsset(asset).burn(account, amount);
    _hubAssetState($, asset, chainId).branchLiquidity -= amount;
  }

  //=========== NOTE: ASSERTIONS ===========//

  function _assertOnlyContract(address addr, string memory paramName) internal view {
    require(addr.code.length > 0, StdError.InvalidParameter(paramName));
  }

  function _assertBranchAssetPairNotExist(StorageV1 storage $, uint256 chainId, address branchAsset) internal view {
    require(
      _branchAssetState($, chainId, branchAsset).hubAsset == address(0),
      IAssetManagerStorageV1__BranchAssetPairNotExist(chainId, branchAsset)
    );
  }
}
