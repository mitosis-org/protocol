// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardDistributor, DistributionType } from '../reward/IRewardDistributor.sol';

interface IEOLRewardRouter {
  event RewardManagerSet(address indexed account);
  event Dispatched(address indexed rewardDistributor, address indexed eolVault, address indexed reward, uint256 amount);
  event EOLShareValueIncreased(address indexed eolVault, uint256 indexed amount);
  event RouteClaimableReward(
    address indexed rewardDistributor,
    address indexed eolVault,
    address indexed reward,
    DistributionType distributionType,
    uint256 amount
  );
  event UnspecifiedReward(
    address indexed eolVault, address indexed reward, uint48 timestamp, uint256 index, uint256 amount
  );

  error IEOLRewardManager__InvalidDispatchRequest(address reward, uint256 index);

  // View functions

  function isRewardManager(address account) external view returns (bool);

  function getRewardTreasuryRewardInfos(address eolVault, address reward_, uint48 timestamp)
    external
    view
    returns (uint256[] memory amounts, bool[] memory dispatched);

  // Mutative function

  function setRewardManager(address account) external;

  function routeExtraRewards(address eolVault, address reward, uint256 amount) external;

  function dispatchTo(
    IRewardDistributor distributor,
    address eolVault,
    address reward,
    uint48 timestamp,
    uint256[] calldata indexes,
    bytes[] calldata metadata
  ) external;

  function dispatchTo(
    IRewardDistributor distributor,
    address eolVault,
    address reward,
    uint48 timestamp,
    uint256 index,
    bytes memory metadata
  ) external;
}
