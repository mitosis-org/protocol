// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { StdTally } from './StdTally.sol';

contract AggregationTally is StdTally {
  address[] public tallies;

  constructor(address[] memory _tallies) {
    for (uint256 i = 0; i < _tallies.length; i++) {
      tallies.push(_tallies[i]);
    }
  }

  function _totalBalance(bytes memory context) internal view override returns (uint256) {
    uint256 totalBalance = 0;
    bytes[] memory contexts = abi.decode(context, (bytes[]));
    for (uint256 i = 0; i < tallies.length; i++) {
      totalBalance += StdTally(tallies[i]).totalBalance(contexts[i]);
    }
    return totalBalance;
  }

  function _pendingDepositBalance(bytes memory context) internal view override returns (uint256) {
    uint256 totalBalance = 0;
    bytes[] memory contexts = abi.decode(context, (bytes[]));
    for (uint256 i = 0; i < tallies.length; i++) {
      totalBalance += StdTally(tallies[i]).pendingDepositBalance(contexts[i]);
    }
    return totalBalance;
  }

  function _pendingWithdrawBalance(bytes memory context) internal view override returns (uint256) {
    uint256 totalBalance = 0;
    bytes[] memory contexts = abi.decode(context, (bytes[]));
    for (uint256 i = 0; i < tallies.length; i++) {
      totalBalance += StdTally(tallies[i]).pendingWithdrawBalance(contexts[i]);
    }
    return totalBalance;
  }
}
