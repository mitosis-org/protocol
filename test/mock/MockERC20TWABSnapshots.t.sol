// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ERC20TWABSnapshots } from '../../src/twab/ERC20TWABSnapshots.sol';

contract MockERC20TWABSnapshots is ERC20TWABSnapshots {
  function initialize(string memory name, string memory symbol) external initializer {
    __ERC20_init(name, symbol);
  }

  function mint(address account, uint256 value) external {
    _mint(account, value);
  }
}
