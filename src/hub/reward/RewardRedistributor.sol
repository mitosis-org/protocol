// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { EnumerableMap } from '@oz-v5/utils/structs/EnumerableMap.sol';

import { AccessControlEnumerableUpgradeable } from '@ozu-v5/access/extensions/AccessControlEnumerableUpgradeable.sol';

import { RewardRedistributorStorageV1 } from './RewardRedistributorStorageV1.sol';
import { IRewardRedistributor } from '../../interfaces/hub/reward/IRewardRedistributor.sol';
import { IMerkleRewardDistributor } from '../../interfaces/hub/reward/IMerkleRewardDistributor.sol';
import { ITWABRewardDistributor } from '../../interfaces/hub/reward/ITWABRewardDistributor.sol';

contract RewardRedistributor is IRewardRedistributor, RewardRedistributorStorageV1, AccessControlEnumerableUpgradeable {
  using EnumerableMap for EnumerableMap.AddressToUintMap;

  bytes32 public constant MANAGER_ROLE = keccak256('MANAGER_ROLE');

  // =========== NOTE: INITIALIZATION FUNCTIONS =========== //

  constructor() {
    _disableInitializers();
  }

  function initialize(
    address admin,
    ITWABRewardDistributor twabRewardDistributor,
    IMerkleRewardDistributor merkleRewardDistributor
  ) public initializer {
    __AccessControlEnumerable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);

    StorageV1 storage $ = _getStorageV1();
    $.twabRewardDistributor = twabRewardDistributor;
    $.merkleRewardDistributor = merkleRewardDistributor;

    _moveToNextRedistribution($);
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function redistribution(uint256 id)
    external
    view
    returns (bool exists, address[] memory rewards, uint256[] memory amounts, uint256 merkleStage, bytes32 merkleRoot)
  {
    StorageV1 storage $ = _getStorageV1();

    if (id > $.currentId) return (false, new address[](0), new uint256[](0), 0, 0);

    Redistribution storage redist = $.redistributions[id];

    rewards = new address[](redist.rewards.length());
    amounts = new uint256[](redist.rewards.length());

    for (uint256 i = 0; i < redist.rewards.length(); i++) {
      (address reward, uint256 amount) = redist.rewards.at(i);
      rewards[i] = reward;
      amounts[i] = amount;
    }

    return (true, rewards, amounts, redist.merkleStage, redist.merkleRoot);
  }

  // ============================ NOTE: MANAGER FUNCTIONS ============================ //

  function reserveRewards(uint256 id, address account, address eolVault, address reward, uint48 toTimestamp)
    external
    onlyRole(MANAGER_ROLE)
  {
    StorageV1 storage $ = _getStorageV1();

    require(id == $.currentId, 'RewardRedistributor: redistribution not exists');

    Redistribution storage redist = $.redistributions[id];

    uint256 claimedAmount = $.twabRewardDistributor.claimForRedistribution(account, eolVault, reward, toTimestamp);

    (bool exists, uint256 prevAmount) = redist.rewards.tryGet(reward);
    redist.rewards.set(reward, prevAmount + claimedAmount);

    emit RewardsReserved(id, account, eolVault, reward, toTimestamp, claimedAmount);
  }

  function executeRedistribution(uint256 id, bytes32 merkleRoot)
    external
    onlyRole(MANAGER_ROLE)
    returns (uint256 merkleStage)
  {
    StorageV1 storage $ = _getStorageV1();

    require(id == $.currentId, 'RewardRedistributor: redistribution not exists');

    Redistribution storage redist = $.redistributions[id];

    for (uint256 i = 0; i < redist.rewards.length(); i++) {
      (address reward, uint256 amount) = redist.rewards.at(i);
      IERC20(reward).transfer(address($.merkleRewardDistributor), amount);
    }

    merkleStage = $.merkleRewardDistributor.addStage(merkleRoot);

    redist.merkleStage = merkleStage;
    redist.merkleRoot = merkleRoot;

    emit RedistributionExecuted(id, merkleStage, merkleRoot);

    _moveToNextRedistribution($);

    return merkleStage;
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _moveToNextRedistribution(StorageV1 storage $) internal {
    $.currentId++;
    emit RedistributionCreated($.currentId);
  }
}
