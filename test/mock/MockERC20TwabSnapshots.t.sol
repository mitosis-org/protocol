// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC20TwabSnapshots } from '../../src/twab/ERC20TwabSnapshots.sol';

contract MockERC20TwabSnapshots is ERC20TwabSnapshots {
  function initialize(string memory name, string memory symbol) external initializer {
    __ERC20_init(name, symbol);
  }

  function mint(address account, uint256 value) external {
    _mint(account, value);
  }
}
