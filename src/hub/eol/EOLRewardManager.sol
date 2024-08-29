// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { IERC4626 } from '@oz-v5/interfaces/IERC4626.sol';

import { DistributeType, IEOLRewardConfigurator } from '../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { EOLRewardManagerStorageV1 } from './storage/EOLRewardManagerStorageV1.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { IEOLRewardDistributor } from '../../interfaces/hub/eol/IEOLRewardDistributor.sol';
import { StdError } from '../../lib/StdError.sol';

contract EOLRewardManager is Ownable2StepUpgradeable, EOLRewardManagerStorageV1 {
  error EOLRewardManager__InvalidDispatchRequest(address reward, uint256 index);

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);
  }

  modifier onlyRewardManagerAdmin() {
    _;
  }

  function routeReward(address eolVault, address reward, uint256 amount) external {
    IERC20(reward).transferFrom(msg.sender, address(this), amount);

    StorageV1 storage $ = _getStorageV1();
    DistributeType distributeType = $.rewardConfigurator.getDistributeType(eolVault, reward);

    if (distributeType == DistributeType.Unspecified) {
      _storeToRewardManager(eolVault, reward, amount, uint48(block.timestamp));
      return;
    }

    IEOLRewardDistributor distributor = _distributor($, distributeType);
    bytes memory metadata = _metadata(distributeType);

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

  function _metadata(DistributeType distributeType) internal view returns (bytes memory metadata) {
    if (distributeType == DistributeType.TWAB) {
      metadata = abi.encodePacked(uint48(block.timestamp));
    }
  }

  function _isDispatchableRequest(RewardInfo memory rewardInfo, address asset) internal pure returns (bool) {
    return rewardInfo.asset == asset || !rewardInfo.dispatched || rewardInfo.amount > 0;
  }
}
