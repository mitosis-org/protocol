// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { IERC4626 } from '@oz-v5/interfaces/IERC4626.sol';

import { EOLRewardManagerStorageV1 } from './storage/EOLRewardManagerStorageV1.sol';
import { IEOLRewardDistributor } from '../../interfaces/hub/eol/IEOLRewardDistributor.sol';
import { DistributeType, IEOLRewardConfigurator } from '../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';

contract EOLRewardManager is EOLRewardManagerStorageV1 {
  function routeReward(address eolVault, address reward, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    IERC20(reward).transferFrom(msg.sender, address(this), amount);

    DistributeType distributeType = $.rewardConfigurator.getDistributeType(eolVault, reward);

    if (distributeType == DistributeType.Unspecified) {
      _storeToManager(eolVault, reward, amount, uint48(block.timestamp));
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
    uint256 index,
    bytes memory metadata
  ) external {
    StorageV1 storage $ = _getStorageV1();

    if (!$.rewardConfigurator.isDistributorRegistered(distributor)) {
      revert IEOLRewardConfigurator.IEOLRewardConfigurator__RewardDistributorNotRegistered();
    }

    RewardInfo storage rewardInfo = $.fallbackRewards[eolVault][timestamp][index];

    if (rewardInfo.asset != asset || rewardInfo.dispatched || rewardInfo.amount == 0) {
      revert('invalid');
    }

    _dispatchTo(rewardInfo, distributor, eolVault, asset, metadata);
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

  function _storeToManager(address eolVault, address reward, uint256 amount, uint48 timestamp) internal {
    _getStorageV1().fallbackRewards[eolVault][timestamp].push(RewardInfo(reward, amount, false));
  }
}
