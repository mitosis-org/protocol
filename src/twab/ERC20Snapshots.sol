// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { ERC20Upgradeable } from '@ozu-v5/token/ERC20/ERC20Upgradeable.sol';

import { Snapshots } from './Snapshots.sol';

contract ERC20Snapshots is ERC20Upgradeable, Snapshots {
  error ERC20ExceededSafeSupply(uint256 increasedSupply, uint256 cap);

  function initialize(string memory name, string memory symbol) external initializer {
    __ERC20_init(name, symbol);
  }

  // TODO(ray): auth
  function mint(address target, uint256 amount) external {
    _mint(target, amount);
  }

  // TODO(ray): auth
  function burn(uint256 amount) external {
    _burn(msg.sender, amount);
  }

  function _maxSupply() internal view virtual returns (uint256) {
    return type(uint208).max;
  }

  function _update(address from, address to, uint256 value) internal virtual override {
    super._update(from, to, value);
    if (from == address(0)) {
      uint256 supply = totalSupply();
      uint256 cap = _maxSupply();
      if (supply > cap) {
        revert ERC20ExceededSafeSupply(supply, cap);
      }
    }
    _snapshot(from, to, value);
  }
}
