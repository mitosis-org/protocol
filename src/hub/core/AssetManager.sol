// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { PausableUpgradeable } from '@ozu-v5/utils/PausableUpgradeable.sol';

import { Time } from '@oz-v5/utils/types/Time.sol';

import { IAssetManager } from '../../interfaces/hub/core/IAssetManager.sol';
import { IAssetManagerEntrypoint } from '../../interfaces/hub/core/IAssetManagerEntrypoint.sol';
import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { IMitosisLedger } from '../../interfaces/hub/core/IMitosisLedger.sol';
import { IEOLRewardManager } from '../../interfaces/hub/eol/IEOLRewardManager.sol';
import { IEOLVault } from '../../interfaces/hub/eol/IEOLVault.sol';
import { StdError } from '../../lib/StdError.sol';
import { AssetManagerStorageV1 } from './storage/AssetManagerStorageV1.sol';

contract AssetManager is IAssetManager, PausableUpgradeable, Ownable2StepUpgradeable, AssetManagerStorageV1 {
  //=========== NOTE: EVENT DEFINITIONS ===========//

  event AssetInitialized(uint256 indexed chainId, address asset);
  event EOLInitialized(uint256 indexed chainId, address eolVault, address asset);

  event Deposited(uint256 indexed chainId, address indexed asset, address indexed to, uint256 amount);
  event Redeemed(uint256 indexed chainId, address indexed asset, address indexed to, uint256 amount);

  event RewardSettled(uint256 indexed chainId, address indexed eolVault, address indexed asset, uint256 amount);
  event LossSettled(uint256 indexed chainId, address indexed eolVault, address indexed asset, uint256 amount);

  event EOLShareValueDecreased(address indexed eolVault, uint256 indexed amount);

  event EOLAllocated(uint256 indexed chainId, address indexed eolVault, uint256 amount);
  event EOLDeallocated(uint256 indexed chainId, address indexed eolVault, uint256 amount);

  event AssetPairSet(address hubAsset, uint256 branchChainId, address branchAsset);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error AssetManager__EOLInsufficient(address eolVault);
  error AssetManager__EOLRewardManagerNotSet();
  error AssetManager__BranchAssetPairNotExist(address asset);

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_, address optOutQueue_) public initializer {
    __Pausable_init();
    __Ownable2Step_init();
    _transferOwnership(owner_);

    StorageV1 storage $ = _getStorageV1();

    _setOptOutQueue($, optOutQueue_);
  }

  //=========== NOTE: ASSET FUNCTIONS ===========//

  function deposit(uint256 chainId, address branchAsset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertBranchAssetPairExist($, chainId, branchAsset);
    _assertOnlyEntrypoint($);

    address hubAsset = $.hubAssets[chainId][branchAsset];
    _mint(hubAsset, to, amount);

    emit Deposited(chainId, hubAsset, to, amount);
  }

  function redeem(uint256 chainId, address hubAsset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    if (to == address(0)) revert StdError.ZeroAddress('to');
    if (amount == 0) revert StdError.ZeroAmount();

    address branchAsset = $.branchAssets[hubAsset][chainId];
    _assertBranchAssetPairExist($, chainId, branchAsset);

    _burn(hubAsset, _msgSender(), amount);
    $.entrypoint.redeem(chainId, branchAsset, to, amount);

    emit Redeemed(chainId, hubAsset, to, amount);
  }

  //=========== NOTE: EOL FUNCTIONS ===========//

  /// @dev only strategist
  function allocateEOL(uint256 chainId, address eolVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyStrategist($, eolVault);

    uint256 eolIdle_ = _eolIdle($, eolVault);
    if (eolIdle_ < amount) revert AssetManager__EOLInsufficient(eolVault);

    $.entrypoint.allocateEOL(chainId, eolVault, amount);
    $.eolStates[eolVault].allocation += amount;

    emit EOLAllocated(chainId, eolVault, amount);
  }

  /// @dev only entrypoint
  function deallocateEOL(uint256 chainId, address eolVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);

    $.eolStates[eolVault].allocation -= amount;

    emit EOLDeallocated(chainId, eolVault, amount);
  }

  /// @dev only entrypoint
  function settleYield(uint256 chainId, address eolVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertEOLRewardManagerSet($);

    address asset = IEOLVault(eolVault).asset();

    _mint(asset, address(this), amount);
    emit RewardSettled(chainId, eolVault, asset, amount);

    _addAllowance(address($.rewardManager), asset, amount);
    $.rewardManager.routeYield(eolVault, amount);
  }

  /// @dev only entrypoint
  function settleLoss(uint256 chainId, address eolVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertEOLRewardManagerSet($);

    // Decrease EOLVault's shares value.
    address asset = IEOLVault(eolVault).asset();
    _burn(asset, eolVault, amount);

    emit LossSettled(chainId, eolVault, asset, amount);
  }

  /// @dev only entrypoint
  function settleExtraRewards(uint256 chainId, address eolVault, address reward, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertBranchAssetPairExist($, chainId, reward);
    _assertEOLRewardManagerSet($);
    _assertOnlyEntrypoint($);

    address hubAsset = $.hubAssets[chainId][reward];
    _mint(reward, address(this), amount);
    emit RewardSettled(chainId, eolVault, hubAsset, amount);

    _addAllowance(address($.rewardManager), hubAsset, amount);
    $.rewardManager.routeExtraReward(eolVault, hubAsset, amount);
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function initializeAsset(uint256 chainId, address hubAsset) external onlyOwner {
    _assertOnlyContract(hubAsset, 'hubAsset');

    StorageV1 storage $ = _getStorageV1();

    address branchAsset = $.branchAssets[hubAsset][chainId];
    _assertBranchAssetPairExist($, chainId, branchAsset);

    $.entrypoint.initializeAsset(chainId, branchAsset);
    emit AssetInitialized(chainId, branchAsset);
  }

  function setAssetPair(address hubAsset, uint256 branchChainId, address branchAsset) external onlyOwner {
    _assertOnlyContract(address(hubAsset), 'hubAsset');
    _assertOnlyContract(address(branchAsset), 'branchAsset');

    // TODO(ray): handle already initialized asset through initializeAsset.
    //
    // https://github.com/mitosis-org/protocol/pull/23#discussion_r1728680943
    StorageV1 storage $ = _getStorageV1();
    $.branchAssets[hubAsset][branchChainId] = branchAsset;
    $.hubAssets[branchChainId][branchAsset] = hubAsset;
    emit AssetPairSet(hubAsset, branchChainId, branchAsset);
  }

  function setEntrypoint(address entrypoint_) external onlyOwner {
    _setEntrypoint(_getStorageV1(), entrypoint_);
  }

  function setOptOutQueue(address optOutQueue_) external onlyOwner {
    _setOptOutQueue(_getStorageV1(), optOutQueue_);
  }

  function setRewardManager(address rewardManager_) external onlyOwner {
    _setRewardManager(_getStorageV1(), rewardManager_);
  }

  function initializeEOL(uint256 chainId, address eolVault) external onlyOwner {
    _assertOnlyContract(eolVault, 'eolVault');

    StorageV1 storage $ = _getStorageV1();

    address hubAsset = IEOLVault(eolVault).asset();
    address branchAsset = $.branchAssets[hubAsset][chainId];
    _assertBranchAssetPairExist($, chainId, branchAsset);

    $.entrypoint.initializeEOL(chainId, eolVault, branchAsset);
    emit EOLInitialized(chainId, eolVault, branchAsset);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _increaseEOLShareValue(address eolVault, uint256 assets) internal {
    IHubAsset(IEOLVault(eolVault).asset()).mint(eolVault, assets);
  }

  function _decreaseEOLShareValue(address eolVault, uint256 assets) internal {
    IHubAsset(IEOLVault(eolVault).asset()).burn(eolVault, assets);
  }

  function _mint(address asset, address account, uint256 amount) internal {
    IHubAsset(asset).mint(account, amount);
  }

  function _burn(address asset, address account, uint256 amount) internal {
    IHubAsset(asset).burn(account, amount);
  }

  //=========== NOTE: ASSERTIONS ===========//

  function _addAllowance(address to, address asset, uint256 amount) internal {
    uint256 prevAllowance = IHubAsset(asset).allowance(address(this), address(to));
    IHubAsset(asset).approve(address(to), prevAllowance + amount);
  }

  function _assertOnlyContract(address addr, string memory paramName) internal view {
    if (addr.code.length == 0) revert StdError.InvalidParameter(paramName);
  }

  function _assertBranchAssetPairExist(StorageV1 storage $, uint256 chainId, address branchAsset_)
    internal
    view
    override
  {
    if ($.hubAssets[chainId][branchAsset_] == address(0)) revert AssetManager__BranchAssetPairNotExist(branchAsset_);
  }

  function _assertEOLRewardManagerSet(StorageV1 storage $) internal view override {
    if (address($.rewardManager) == address(0)) revert AssetManager__EOLRewardManagerNotSet();
  }
}
