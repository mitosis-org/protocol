// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IEOLAllocationGovernorStorageV1 {
  function voters(uint256 chainId) external view returns (address[] memory);

  function lastEpochId() external view returns (uint256);

  function totalVotingPower(uint256 epochId) external view returns (uint256);

  function protocolIds(uint256 epochId, uint256 chainId) external view returns (uint256[] memory);
}

interface IEOLAllocationGovernor is IEOLAllocationGovernorStorageV1 {
  function setEpochPeriod(uint32 epochPeriod) external;

  function voteResult(uint256 epochId, uint256 chainId, address account)
    external
    view
    returns (bool hasVoted, uint256 votingPower, uint256 gaugeSum, uint32[] memory gauges);
}
