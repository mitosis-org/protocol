// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { DistributionType } from './IEOLRewardConfigurator.sol';

interface IEOLRewardDistributor {
  function distributionType() external view returns (DistributionType);

  function description() external view returns (string memory);

  // See the `src/hub/eol/LibDistributorRewardMetadata`.
  function claimable(address account, address eolVault, address asset, bytes memory metadata)
    external
    view
    returns (bool);
  function handleReward(address eolVault, address asset, uint256 amount, bytes memory metadata) external;
}
