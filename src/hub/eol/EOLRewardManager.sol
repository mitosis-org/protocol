// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { IERC4626 } from '@oz-v5/interfaces/IERC4626.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { IEOLRewardConfigurator } from '../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { IEOLRewardManager } from '../../interfaces/hub/eol/IEOLRewardManager.sol';
import { IEOLVault } from '../../interfaces/hub/eol/IEOLVault.sol';
import { IRewardDistributor, DistributionType } from '../../interfaces/hub/reward/IRewardDistributor.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';
import { LibDistributorRewardMetadata, RewardTWABMetadata } from '../reward/LibDistributorRewardMetadata.sol';
import { EOLRewardManagerStorageV1 } from './EOLRewardManagerStorageV1.sol';

contract EOLRewardManager is IEOLRewardManager, Ownable2StepUpgradeable, EOLRewardManagerStorageV1 {
  using LibDistributorRewardMetadata for RewardTWABMetadata;

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner, address assetManager, address eolRewardConfigurator) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);

    StorageV1 storage $ = _getStorageV1();
    $.assetManager = assetManager;
    $.rewardConfigurator = IEOLRewardConfigurator(eolRewardConfigurator);
  }

  // TODO(ray): must be set when introdue RoleManager
  modifier onlyRewardManagerAdmin() {
    require(_getStorageV1().isRewardManager[_msgSender()], StdError.Unauthorized());
    _;
  }

  modifier onlyAssetManager() {
    require(_msgSender() == _getStorageV1().assetManager, StdError.Unauthorized());
    _;
  }

  // View functions

  function isRewardManager(address account) external view returns (bool) {
    return _getStorageV1().isRewardManager[account];
  }

  function getRewardTreasuryRewardInfos(address eolVault, address reward_, uint48 timestamp)
    external
    view
    returns (uint256[] memory amounts, bool[] memory dispatched)
  {
    RewardInfo[] storage rewardInfos = _getStorageV1().rewardTreasury[eolVault][timestamp];

    uint256 counts;
    for (uint256 i = 0; i < rewardInfos.length; i++) {
      if (rewardInfos[i].asset == reward_) counts++;
    }

    amounts = new uint256[](counts);
    dispatched = new bool[](counts);
    for (uint256 i = 0; i < rewardInfos.length; i++) {
      if (rewardInfos[i].asset == reward_) {
        amounts[i] = rewardInfos[i].amount;
        dispatched[i] = rewardInfos[i].dispatched;
      }
    }
  }

  // Mutative functions

  function setRewardManager(address account) external onlyOwner {
    _getStorageV1().isRewardManager[account] = true;
    emit RewardManagerSet(account);
  }

  function routeYield(address eolVault, uint256 amount) external onlyAssetManager {
    address reward = IEOLVault(eolVault).asset();
    IHubAsset(reward).transferFrom(_msgSender(), address(this), amount);
    _increaseEOLShareValue(eolVault, amount);
  }

  function routeExtraRewards(address eolVault, address reward, uint256 amount) external onlyAssetManager {
    IHubAsset(reward).transferFrom(_msgSender(), address(this), amount);
    _routeEOLClaimableReward(_getStorageV1(), eolVault, reward, amount);
  }

  function dispatchTo(
    IRewardDistributor distributor,
    address eolVault,
    address reward,
    uint48 timestamp,
    uint256[] calldata indexes,
    bytes[] calldata metadata
  ) external onlyRewardManagerAdmin {
    require(indexes.length == metadata.length, StdError.InvalidParameter('metadata'));

    StorageV1 storage $ = _getStorageV1();

    _assertDistributorRegistered($, distributor);

    for (uint256 i = 0; i < indexes.length; i++) {
      _processDispatch($, distributor, eolVault, reward, timestamp, indexes[i], metadata[i]);
    }
  }

  function dispatchTo(
    IRewardDistributor distributor,
    address eolVault,
    address reward,
    uint48 timestamp,
    uint256 index,
    bytes memory metadata
  ) external onlyRewardManagerAdmin {
    StorageV1 storage $ = _getStorageV1();

    _assertDistributorRegistered($, distributor);

    _processDispatch($, distributor, eolVault, reward, timestamp, index, metadata);
  }

  function _routeEOLClaimableReward(StorageV1 storage $, address eolVault, address reward, uint256 amount) internal {
    bytes memory metadata;
    if ($.rewardConfigurator.distributionType(eolVault, reward) == DistributionType.TWAB) {
      metadata = RewardTWABMetadata(eolVault, Time.timestamp()).encode();
    }

    _routeClaimableReward($, eolVault, reward, amount, metadata);
  }

  function _increaseEOLShareValue(address eolVault, uint256 assets) internal {
    address reward = IEOLVault(eolVault).asset();
    IHubAsset(reward).transfer(eolVault, assets);
    emit EOLShareValueIncreased(eolVault, assets);
  }

  function _routeClaimableReward(
    StorageV1 storage $,
    address eolVault,
    address reward,
    uint256 amount,
    bytes memory metadata
  ) internal {
    DistributionType distributionType = $.rewardConfigurator.distributionType(eolVault, reward);

    if (distributionType == DistributionType.Unspecified) {
      _storeToRewardManager($, eolVault, reward, amount, Time.timestamp());
      return;
    }

    IRewardDistributor distributor = _distributor($, distributionType);

    IERC20(reward).approve(address(distributor), amount);
    distributor.handleReward(eolVault, reward, amount, metadata);
    emit RouteClaimableReward(address(distributor), eolVault, reward, distributionType, amount);
  }

  function _processDispatch(
    StorageV1 storage $,
    IRewardDistributor distributor,
    address eolVault,
    address reward,
    uint48 timestamp,
    uint256 index,
    bytes memory metadata
  ) internal {
    RewardInfo storage rewardInfo = $.rewardTreasury[eolVault][timestamp][index];

    require(_isDispatchableRequest(rewardInfo, reward), IEOLRewardManager__InvalidDispatchRequest(reward, index));

    _dispatchTo(rewardInfo, distributor, eolVault, reward, metadata);
  }

  function _dispatchTo(
    RewardInfo storage rewardInfo,
    IRewardDistributor distributor,
    address eolVault,
    address reward,
    bytes memory metadata
  ) internal {
    rewardInfo.dispatched = true;

    uint256 amount = rewardInfo.amount;
    IERC20(reward).approve(address(distributor), amount);

    distributor.handleReward(eolVault, reward, amount, metadata);

    emit Dispatched(address(distributor), eolVault, reward, amount);
  }

  function _storeToRewardManager(
    StorageV1 storage $,
    address eolVault,
    address reward,
    uint256 amount,
    uint48 timestamp
  ) internal {
    RewardInfo[] storage rewardInfos = $.rewardTreasury[eolVault][timestamp];
    rewardInfos.push(RewardInfo(reward, amount, false));
    emit UnspecifiedReward(eolVault, reward, timestamp, rewardInfos.length, amount);
  }

  function _distributor(StorageV1 storage $, DistributionType distributionType)
    internal
    view
    returns (IRewardDistributor distributor)
  {
    if (distributionType == DistributionType.TWAB) {
      distributor = $.rewardConfigurator.defaultDistributor(DistributionType.TWAB);
    } else if (distributionType == DistributionType.MerkleProof) {
      distributor = $.rewardConfigurator.defaultDistributor(DistributionType.MerkleProof);
    } else {
      revert StdError.NotImplemented();
    }
  }

  function _isDispatchableRequest(RewardInfo memory rewardInfo, address reward) internal pure returns (bool) {
    return rewardInfo.asset == reward || !rewardInfo.dispatched || rewardInfo.amount > 0;
  }

  function _assertDistributorRegistered(StorageV1 storage $, IRewardDistributor distributor) internal view {
    require(
      $.rewardConfigurator.isDistributorRegistered(distributor),
      IEOLRewardConfigurator.IEOLRewardConfigurator__RewardDistributorNotRegistered()
    );
  }
}
