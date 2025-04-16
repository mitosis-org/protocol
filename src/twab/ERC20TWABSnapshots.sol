// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ECDSA } from '@oz-v5/utils/cryptography/ECDSA.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { ERC20Upgradeable } from '@ozu-v5/token/ERC20/ERC20Upgradeable.sol';

import { IDelegationRegistry } from '../interfaces/hub/core/IDelegationRegistry.sol';
import { StdError } from '../lib/StdError.sol';
import { TWABCheckpoints } from '../lib/TWABCheckpoints.sol';
import { TWABSnapshots } from './TWABSnapshots.sol';

abstract contract ERC20TWABSnapshots is ERC20Upgradeable, TWABSnapshots {
  /**
   * @dev Total supply cap has been exceeded, introducing a risk of votes overflowing.
   */
  error ERC20ExceededSafeSupply(uint256 increasedSupply, uint256 cap);

  function __ERC20TWABSnapshots_init(address delegationRegistry_, string memory name_, string memory symbol_) internal {
    __ERC20_init_unchained(name_, symbol_);
    __TWABSnapshots_init(delegationRegistry_);
  }

  function _maxSupply() internal view virtual returns (uint256) {
    return type(uint208).max;
  }

  function _update(address from, address to, uint256 value) internal virtual override {
    super._update(from, to, value);
    if (from == address(0)) {
      uint256 supply = totalSupply();
      uint256 cap = _maxSupply();
      require(supply <= cap, ERC20ExceededSafeSupply(supply, cap));
    }

    TWABSnapshotsStorageV1_ storage $ = _getTWABSnapshotsStorageV1();

    _snapshotBalance($, from, to);
    _snapshotDelegate($, from, to, value);
  }

  function _getTotalSupply() internal view override returns (uint256) {
    return totalSupply();
  }

  function _getBalance(address account) internal view override returns (uint256) {
    return balanceOf(account);
  }
}
