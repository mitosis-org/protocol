// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { IERC4626 } from '@oz-v5/interfaces/IERC4626.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { DistributionType, IEOLRewardConfigurator } from '../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { IEOLRewardDistributor } from '../../interfaces/hub/eol/IEOLRewardDistributor.sol';
import { IEOLRewardManager } from '../../interfaces/hub/eol/IEOLRewardManager.sol';
import { IEOLVault } from '../../interfaces/hub/eol/IEOLVault.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';
import { DistributorHandleRewardMetadataLib, HandleRewardTWABMetadata } from './DistributorHandleRewardMetadataLib.sol';
import { EOLRewardManagerStorageV1 } from './storage/EOLRewardManagerStorageV1.sol';

contract EOLRewardManager is IEOLRewardManager, Ownable2StepUpgradeable, EOLRewardManagerStorageV1 {
  using DistributorHandleRewardMetadataLib for HandleRewardTWABMetadata;

  event DispatchedTo(
    address indexed rewardDistributor, address indexed eolVault, address indexed reward, uint256 amount
  );
  event EOLShareValueIncreased(address indexed eolVault, uint256 indexed amount);
  event RouteClaimableReward(
    address indexed rewardDistributor,
    address indexed eolVault,
    address indexed reward,
    DistributionType distributionType,
    uint256 amount
  );
  event UnspecifiedReward(address indexed eolVault, address indexed reward, uint48 timestamp, uint256 amount);

  error EOLRewardManager__InvalidDispatchRequest(address reward, uint256 index);

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner, address assetManager) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);
    _getStorageV1().assetManager = assetManager;
  }

  modifier onlyRewardManagerAdmin() {
    _;
  }

  modifier onlyAssetManager() {
    if (_msgSender() != _getStorageV1().assetManager) revert StdError.Unauthorized();
    _;
  }

  function routeYield(address eolVault, uint256 amount) external onlyAssetManager {
    address reward = IEOLVault(eolVault).asset();
    IHubAsset(reward).transferFrom(_msgSender(), address(this), amount);

    (uint256 eolAssetHolderReward, uint256 hubAssetHolderReward) = _calcReward(_getStorageV1(), amount);

    _increaseEOLShareValue(eolVault, eolAssetHolderReward);
    _routeHubAssetHolderClaimableReward(eolVault, reward, hubAssetHolderReward);
  }

  function routeExtraReward(address eolVault, address reward, uint256 amount) external onlyAssetManager {
    IHubAsset(reward).transferFrom(_msgSender(), address(this), amount);

    (uint256 eolAssetHolderReward, uint256 hubAssetHolderReward) = _calcReward(_getStorageV1(), amount);
    _routeEOLClaimableReward(eolVault, reward, eolAssetHolderReward);
    _routeHubAssetHolderClaimableReward(eolVault, reward, hubAssetHolderReward);
  }

  function dispatchTo(
    IEOLRewardDistributor distributor,
    address eolVault,
    address asset,
    uint48 timestamp,
    uint256[] calldata indexes,
    bytes[] calldata metadata
  ) external onlyRewardManagerAdmin {
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
  ) external onlyRewardManagerAdmin {
    StorageV1 storage $ = _getStorageV1();

    if (!$.rewardConfigurator.isDistributorRegistered(distributor)) {
      revert IEOLRewardConfigurator.IEOLRewardConfigurator__RewardDistributorNotRegistered();
    }

    _processDispatch(distributor, eolVault, asset, timestamp, index, metadata);
  }

  function _calcReward(StorageV1 storage $, uint256 totalAmount)
    internal
    view
    returns (uint256 eolAssetHolderReward, uint256 hubAssetHolderReward)
  {
    uint256 eolAssetHolderRatio = $.rewardConfigurator.getEOLAssetHolderRewardRatio();
    uint256 precision = $.rewardConfigurator.getRewardRatioPrecision();
    eolAssetHolderReward = Math.mulDiv(totalAmount, eolAssetHolderRatio, precision);
    hubAssetHolderReward = totalAmount - eolAssetHolderReward;
  }

  function _routeEOLClaimableReward(address eolVault, address reward, uint256 amount) internal {
    bytes memory metadata;
    if (_getStorageV1().rewardConfigurator.getDistributionType(eolVault, reward) == DistributionType.TWAB) {
      metadata = HandleRewardTWABMetadata(eolVault, Time.timestamp()).encode();
    }

    _routeClaimableReward(eolVault, reward, amount, metadata);
  }

  function _routeHubAssetHolderClaimableReward(address eolVault, address reward, uint256 amount) internal {
    bytes memory metadata;
    if (_getStorageV1().rewardConfigurator.getDistributionType(eolVault, reward) == DistributionType.TWAB) {
      address underlyingAsset = IEOLVault(eolVault).asset();
      metadata = HandleRewardTWABMetadata(underlyingAsset, Time.timestamp()).encode();
    }

    _routeClaimableReward(eolVault, reward, amount, metadata);
  }

  function _increaseEOLShareValue(address eolVault, uint256 assets) internal {
    address reward = IEOLVault(eolVault).asset();
    IHubAsset(reward).transfer(eolVault, assets);
    emit EOLShareValueIncreased(eolVault, assets);
  }

  function _routeClaimableReward(address eolVault, address reward, uint256 amount, bytes memory metadata) internal {
    StorageV1 storage $ = _getStorageV1();
    DistributionType distributionType = $.rewardConfigurator.getDistributionType(eolVault, reward);

    if (distributionType == DistributionType.Unspecified) {
      _storeToRewardManager(eolVault, reward, amount, Time.timestamp());
      return;
    }

    IEOLRewardDistributor distributor = _distributor($, distributionType);

    IERC20(reward).approve(address(distributor), amount);
    distributor.handleReward(eolVault, reward, amount, metadata);
    emit RouteClaimableReward(address(distributor), eolVault, reward, distributionType, amount);
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
      revert EOLRewardManager__InvalidDispatchRequest(asset, index);
    }

    _dispatchTo(rewardInfo, distributor, eolVault, asset, metadata);
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

    emit DispatchedTo(address(distributor), eolVault, asset, amount);
  }

  function _storeToRewardManager(address eolVault, address reward, uint256 amount, uint48 timestamp) internal {
    _getStorageV1().rewardTreasury[eolVault][timestamp].push(RewardInfo(reward, amount, false));
    emit UnspecifiedReward(eolVault, reward, timestamp, amount);
  }

  function _distributor(StorageV1 storage $, DistributionType distributionType)
    internal
    view
    returns (IEOLRewardDistributor distributor)
  {
    if (distributionType == DistributionType.TWAB) {
      distributor = $.rewardConfigurator.getDefaultDistributor(DistributionType.TWAB);
    } else if (distributionType == DistributionType.MerkleProof) {
      distributor = $.rewardConfigurator.getDefaultDistributor(DistributionType.MerkleProof);
    } else {
      revert StdError.NotImplemented();
    }
  }

  function _isDispatchableRequest(RewardInfo memory rewardInfo, address asset) internal pure returns (bool) {
    return rewardInfo.asset == asset || !rewardInfo.dispatched || rewardInfo.amount > 0;
  }
}
