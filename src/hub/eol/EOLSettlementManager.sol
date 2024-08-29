// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { IERC4626 } from '@oz-v5/interfaces/IERC4626.sol';

import { DistributeType, IEOLRewardConfigurator } from '../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { EOLSettlementManagerStorageV1 } from './storage/EOLSettlementManagerStorageV1.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { IEOLRewardDistributor } from '../../interfaces/hub/eol/IEOLRewardDistributor.sol';
import { IEOLVault } from '../../interfaces/hub/eol/IEOLVault.sol';
import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { RewardDispatchMetadataLib, TWABDispatchMetadata } from './RewardDispatchMetadataLib.sol';
import { StdError } from '../../lib/StdError.sol';

contract EOLSettlementManager is Ownable2StepUpgradeable, EOLSettlementManagerStorageV1 {
  using RewardDispatchMetadataLib for TWABDispatchMetadata;

  error EOLSettlementManager__InvalidDispatchRequest(address reward, uint256 index);

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner, address assetManager) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);
    _getStorageV1().assetManager = assetManager;
  }

  modifier onlySettlementManagerAdmin() {
    _;
  }

  modifier onlyAssetManager() {
    if (_msgSender() != _getStorageV1().assetManager) revert StdError.Unauthorized();
    _;
  }

  function settleYield(address eolVault, uint256 amount) external onlyAssetManager {
    address reward = IEOLVault(eolVault).asset();

    // TODO
    uint256 hubAssetHolderReward;
    uint256 miAssetHolderRewrad;

    _increaseEOLShareValue(eolVault, miAssetHolderRewrad);
    _routeHubAssetHolderClaimableReward(eolVault, reward, hubAssetHolderReward);
  }

  function settleLoss(address eolVault, uint256 amount) external onlyAssetManager {
    _decreaseEOLShareValue(eolVault, amount);
  }

  function settleExtraReward(address eolVault, address reward, uint256 amount) external onlyAssetManager {
    // TODO
    uint256 hubAssetHolderReward;
    uint256 miAssetHolderRewrad;

    _routeEOLClaimableReward(eolVault, reward, miAssetHolderRewrad);
    _routeHubAssetHolderClaimableReward(eolVault, reward, hubAssetHolderReward);
  }

  function _routeEOLClaimableReward(address eolVault, address reward, uint256 amount) internal {
    bytes memory metadata;
    if (_getStorageV1().rewardConfigurator.getDistributeType(eolVault, reward) == DistributeType.TWAB) {
      metadata = TWABDispatchMetadata(eolVault, uint48(block.timestamp)).encode();
    }

    _routeClaimableReward(eolVault, reward, amount, metadata);
  }

  function _routeHubAssetHolderClaimableReward(address eolVault, address reward, uint256 amount) internal {
    bytes memory metadata;
    if (_getStorageV1().rewardConfigurator.getDistributeType(eolVault, reward) == DistributeType.TWAB) {
      address underlyingAsset = IEOLVault(eolVault).asset();
      metadata = TWABDispatchMetadata(underlyingAsset, uint48(block.timestamp)).encode();
    }

    _routeClaimableReward(eolVault, reward, amount, metadata);
  }

  function _routeClaimableReward(address eolVault, address reward, uint256 amount, bytes memory metadata) internal {
    IHubAsset(reward).mint(address(this), amount);

    StorageV1 storage $ = _getStorageV1();
    DistributeType distributeType = $.rewardConfigurator.getDistributeType(eolVault, reward);

    if (distributeType == DistributeType.Unspecified) {
      _storeToRewardManager(eolVault, reward, amount, uint48(block.timestamp));
      return;
    }

    IEOLRewardDistributor distributor = _distributor($, distributeType);

    IERC20(reward).approve(address(distributor), amount);
    distributor.handleReward(eolVault, reward, amount, metadata);
  }

  function dispatchTo(
    IEOLRewardDistributor distributor,
    address eolVault,
    address asset,
    uint48 timestamp,
    uint256[] calldata indexes,
    bytes[] calldata metadata
  ) external onlySettlementManagerAdmin {
    if (indexes.length != metadata.length) revert StdError.InvalidParameter('metadata');

    StorageV1 storage $ = _getStorageV1();

    if (!$.rewardConfigurator.isDistributorRegistered(distributor)) {
      revert IEOLRewardConfigurator.IEOLRewardConfigurator__RewardDistributorNotRegistered();
    }

    for (uint256 i = 0; i < indexes.length; i++) {
      _processDispatch(distributor, eolVault, asset, timestamp, indexes[i], metadata[i]);
    }
  }

  function dispatchTo(
    IEOLRewardDistributor distributor,
    address eolVault,
    address asset,
    uint48 timestamp,
    uint256 index,
    bytes memory metadata
  ) external onlySettlementManagerAdmin {
    StorageV1 storage $ = _getStorageV1();

    if (!$.rewardConfigurator.isDistributorRegistered(distributor)) {
      revert IEOLRewardConfigurator.IEOLRewardConfigurator__RewardDistributorNotRegistered();
    }

    _processDispatch(distributor, eolVault, asset, timestamp, index, metadata);
  }

  function _processDispatch(
    IEOLRewardDistributor distributor,
    address eolVault,
    address asset,
    uint48 timestamp,
    uint256 index,
    bytes memory metadata
  ) internal {
    RewardInfo storage rewardInfo = _getStorageV1().rewardTreasury[eolVault][timestamp][index];

    if (!_isDispatchableRequest(rewardInfo, asset)) {
      revert EOLSettlementManager__InvalidDispatchRequest(asset, index);
    }

    _dispatchTo(rewardInfo, distributor, eolVault, asset, metadata);
  }

  function _increaseEOLShareValue(address eolVault, uint256 assets) internal {
    IHubAsset(IEOLVault(eolVault).asset()).mint(eolVault, assets);
  }

  function _decreaseEOLShareValue(address eolVault, uint256 assets) internal {
    IHubAsset(IEOLVault(eolVault).asset()).burn(eolVault, assets);
  }

  function _dispatchTo(
    RewardInfo storage rewardInfo,
    IEOLRewardDistributor distributor,
    address eolVault,
    address asset,
    bytes memory metadata
  ) internal {
    rewardInfo.dispatched = true;

    uint256 amount = rewardInfo.amount;
    IERC20(asset).approve(address(distributor), amount);

    distributor.handleReward(eolVault, asset, amount, metadata);
  }

  function _storeToRewardManager(address eolVault, address reward, uint256 amount, uint48 timestamp) internal {
    _getStorageV1().rewardTreasury[eolVault][timestamp].push(RewardInfo(reward, amount, false));
  }

  function _distributor(StorageV1 storage $, DistributeType distributeType)
    internal
    view
    returns (IEOLRewardDistributor distributor)
  {
    if (distributeType == DistributeType.TWAB) {
      distributor = $.rewardConfigurator.getDefaultDistributor(DistributeType.TWAB);
    }

    if (distributeType == DistributeType.MerkleProof) {
      distributor = $.rewardConfigurator.getDefaultDistributor(DistributeType.MerkleProof);
    }
  }

  function _isDispatchableRequest(RewardInfo memory rewardInfo, address asset) internal pure returns (bool) {
    return rewardInfo.asset == asset || !rewardInfo.dispatched || rewardInfo.amount > 0;
  }
}
