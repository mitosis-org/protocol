// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

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
import { EOLRewardManagerStorageV1 } from './EOLRewardManagerStorageV1.sol';
import { LibDistributorHandleRewardMetadata, HandleRewardTWABMetadata } from './LibDistributorHandleRewardMetadata.sol';

contract EOLRewardManager is IEOLRewardManager, Ownable2StepUpgradeable, EOLRewardManagerStorageV1 {
  using LibDistributorHandleRewardMetadata for HandleRewardTWABMetadata;

  event Dispatched(address indexed rewardDistributor, address indexed eolVault, address indexed reward, uint256 amount);
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

  // TODO(ray): must be set when introdue RoleManager
  modifier onlyRewardManagerAdmin() {
    _;
  }

  modifier onlyAssetManager() {
    require(_msgSender() == _getStorageV1().assetManager, StdError.Unauthorized());
    _;
  }

  function routeYield(address eolVault, uint256 amount) external onlyAssetManager {
    address reward = IEOLVault(eolVault).asset();
    IHubAsset(reward).transferFrom(_msgSender(), address(this), amount);

    StorageV1 storage $ = _getStorageV1();

    (uint256 eolAssetHolderReward, uint256 hubAssetHolderReward) = _calcReward($, amount);

    _increaseEOLShareValue(eolVault, eolAssetHolderReward);
    _routeHubAssetHolderClaimableReward($, eolVault, reward, hubAssetHolderReward);
  }

  function routeExtraReward(address eolVault, address reward, uint256 amount) external onlyAssetManager {
    IHubAsset(reward).transferFrom(_msgSender(), address(this), amount);

    StorageV1 storage $ = _getStorageV1();

    (uint256 eolAssetHolderReward, uint256 hubAssetHolderReward) = _calcReward($, amount);

    _routeEOLClaimableReward($, eolVault, reward, eolAssetHolderReward);
    _routeHubAssetHolderClaimableReward($, eolVault, reward, hubAssetHolderReward);
  }

  function dispatchTo(
    IEOLRewardDistributor distributor,
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
    IEOLRewardDistributor distributor,
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

  function _calcReward(StorageV1 storage $, uint256 totalAmount)
    internal
    view
    returns (uint256 eolAssetHolderReward, uint256 hubAssetHolderReward)
  {
    uint256 eolAssetHolderRatio = $.rewardConfigurator.getEOLAssetHolderRewardRatio();
    uint256 precision = $.rewardConfigurator.rewardRatioPrecision();
    eolAssetHolderReward = Math.mulDiv(totalAmount, eolAssetHolderRatio, precision);
    hubAssetHolderReward = totalAmount - eolAssetHolderReward;
  }

  function _routeEOLClaimableReward(StorageV1 storage $, address eolVault, address reward, uint256 amount) internal {
    bytes memory metadata;
    if ($.rewardConfigurator.getDistributionType(eolVault, reward) == DistributionType.TWAB) {
      metadata = HandleRewardTWABMetadata(eolVault, Time.timestamp()).encode();
    }

    _routeClaimableReward($, eolVault, reward, amount, metadata);
  }

  function _routeHubAssetHolderClaimableReward(StorageV1 storage $, address eolVault, address reward, uint256 amount)
    internal
  {
    bytes memory metadata;
    if ($.rewardConfigurator.getDistributionType(eolVault, reward) == DistributionType.TWAB) {
      address underlyingAsset = IEOLVault(eolVault).asset();
      metadata = HandleRewardTWABMetadata(underlyingAsset, Time.timestamp()).encode();
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
    DistributionType distributionType = $.rewardConfigurator.getDistributionType(eolVault, reward);

    if (distributionType == DistributionType.Unspecified) {
      _storeToRewardManager($, eolVault, reward, amount, Time.timestamp());
      return;
    }

    IEOLRewardDistributor distributor = _distributor($, distributionType);

    IERC20(reward).approve(address(distributor), amount);
    distributor.handleReward(eolVault, reward, amount, metadata);
    emit RouteClaimableReward(address(distributor), eolVault, reward, distributionType, amount);
  }

  function _processDispatch(
    StorageV1 storage $,
    IEOLRewardDistributor distributor,
    address eolVault,
    address reward,
    uint48 timestamp,
    uint256 index,
    bytes memory metadata
  ) internal {
    RewardInfo storage rewardInfo = $.rewardTreasury[eolVault][timestamp][index];

    require(_isDispatchableRequest(rewardInfo, reward), EOLRewardManager__InvalidDispatchRequest(reward, index));

    _dispatchTo(rewardInfo, distributor, eolVault, reward, metadata);
  }

  function _dispatchTo(
    RewardInfo storage rewardInfo,
    IEOLRewardDistributor distributor,
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
    $.rewardTreasury[eolVault][timestamp].push(RewardInfo(reward, amount, false));
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

  function _isDispatchableRequest(RewardInfo memory rewardInfo, address reward) internal pure returns (bool) {
    return rewardInfo.asset == reward || !rewardInfo.dispatched || rewardInfo.amount > 0;
  }

  function _assertDistributorRegistered(StorageV1 storage $, IEOLRewardDistributor distributor) internal view {
    require(
      $.rewardConfigurator.isDistributorRegistered(distributor),
      IEOLRewardConfigurator.IEOLRewardConfigurator__RewardDistributorNotRegistered()
    );
  }
}
