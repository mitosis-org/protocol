// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { StdTally } from './StdTally.sol';

interface IManager {
  function totalBalance() external view returns (uint256);
}

contract ManagerTally is StdTally {
  IManager public immutable manager;

  constructor(IManager manager_) {
    manager = manager_;
  }

  function _totalBalance(bytes memory) internal view override returns (uint256) {
    return manager.totalBalance();
  }
}
