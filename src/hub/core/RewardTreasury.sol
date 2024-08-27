// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Time } from '@oz-v5/utils/types/Time.sol';
import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { RewardTreasuryStorageV1 } from './storage/RewardTreasuryStorageV1.sol';
import { IRewardTreasury } from '../../interfaces/hub/core/IRewardTreasury.sol';
import { IMitosisLedger } from '../../interfaces/hub/core/IMitosisLedger.sol';
import { IRewardDistributor } from '../../interfaces/hub/core/IRewardDistributor.sol';
import { StdError } from '../../lib/StdError.sol';

contract RewardTreasury is IRewardTreasury, Ownable2StepUpgradeable, RewardTreasuryStorageV1 {
  event Deposited(uint256 indexed eolId, address indexed asset, uint48 indexed timestamp, uint256 amount);
  event Dispatched(
    uint256 indexed eolId, address indexed asset, uint48 indexed timestamp, address distributor, uint256 amount
  );

  constructor() initializer {
    _disableInitializers();
  }

  function initialize(address owner_, IMitosisLedger mitosisLedger_) public initializer {
    __Ownable2Step_init();
    _transferOwnership(owner_);
    _getStorageV1().mitosisLedger = mitosisLedger_;
  }

  function deposit(uint256 eolId, address asset, uint256 amount) external {
    IERC20(asset).transferFrom(_msgSender(), address(this), amount);

    uint48 timestamp = Time.timestamp();
    _getStorageV1().rewards[eolId][timestamp].push(RewardInfo(asset, amount, false));

    emit Deposited(eolId, asset, timestamp, amount);
  }

  function dispatchTo(IRewardDistributor distributor, uint256 eolId, address asset, uint48 timestamp) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEolStrategist($, eolId);

    RewardInfo[] storage rewardInfos = $.rewards[eolId][timestamp];
    for (uint256 i = 0; i < rewardInfos.length; i++) {
      RewardInfo storage rewardInfo = rewardInfos[i];
      if (rewardInfo.asset == asset && !rewardInfo.dispatched && rewardInfo.amount > 0) {
        _dispatchTo(rewardInfo, distributor, eolId, asset, timestamp);
      }
    }
  }

  function _dispatchTo(
    RewardInfo storage rewardInfo,
    IRewardDistributor distributor,
    uint256 eolId,
    address asset,
    uint48 timestamp
  ) internal {
    rewardInfo.dispatched = true;
    uint256 amount = rewardInfo.amount;

    IERC20(asset).approve(address(distributor), amount);
    distributor.receiveReward(eolId, asset, amount, timestamp);

    emit Dispatched(eolId, asset, timestamp, address(distributor), amount);
  }

  function _assertOnlyEolStrategist(StorageV1 storage $, uint256 eolId) internal view {
    if (_msgSender() != $.mitosisLedger.eolStrategist(eolId)) revert StdError.Unauthorized();
  }
}
