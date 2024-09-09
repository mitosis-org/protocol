// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { DistributionType } from './IEOLRewardConfigurator.sol';

interface IEOLRewardDistributor {
  function distributionType() external view returns (DistributionType);

  function description() external view returns (string memory);

  function claimable(address account, address eolVault, address asset) external view returns (bool);

  // See the `src/hub/eol/DistributorHandleRewardMetadataLib`.
  function handleReward(address eolVault, address asset, uint256 amount, bytes memory metadata) external;
}
