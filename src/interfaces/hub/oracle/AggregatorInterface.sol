// SPDX-License-Identifier: MIT
// Copied from https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/shared/interfaces/AggregatorInterface.sol but event definitions are removed.
pragma solidity ^0.8.0;

// solhint-disable-next-line interface-starts-with-i
interface AggregatorInterface {
  function latestAnswer() external view returns (int256);

  function latestTimestamp() external view returns (uint256);

  function latestRound() external view returns (uint256);

  function getAnswer(uint256 roundId) external view returns (int256);

  function getTimestamp(uint256 roundId) external view returns (uint256);
}
