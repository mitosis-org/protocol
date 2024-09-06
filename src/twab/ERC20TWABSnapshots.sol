// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC20Upgradeable } from '@ozu-v5/token/ERC20/ERC20Upgradeable.sol';

import { TWABSnapshots } from './TWABSnapshots.sol';

abstract contract ERC20TWABSnapshots is ERC20Upgradeable, TWABSnapshots {
  error ERC20ExceededSafeSupply(uint256 increasedSupply, uint256 cap);

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
