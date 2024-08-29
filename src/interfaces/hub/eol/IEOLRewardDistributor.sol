// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { DistributeType } from './IEOLRewardConfigurator.sol';

interface IEOLRewardDistributor {
  function distributeType() external view returns (DistributeType);

  function description() external view returns (string memory);

  function claimable(address account, address eolVault, address asset) external view returns (bool);

  // metadata encoded each distributor's required data. (timestamp, range...)
  function handleReward(address eolVault, address asset, uint256 amount, bytes memory metadata) external;
}
