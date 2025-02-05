// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ERC20Snapshots } from '../../src/twab/ERC20Snapshots.sol';

contract MockERC20Snapshots is ERC20Snapshots {
  function initialize(string memory name, string memory symbol) external initializer {
    __ERC20Snapshots_init(name, symbol);
  }

  function mint(address account, uint256 value) external {
    _mint(account, value);
  }
}
