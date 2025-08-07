// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

interface IReclaimQueueCollector {
  event Collected(address indexed vault, address indexed asset, uint256 collected);

  function collect(address vault, address asset, uint256 collected) external;
}
