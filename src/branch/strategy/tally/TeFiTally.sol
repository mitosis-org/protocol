// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from '@oz/token/ERC20/IERC20.sol';

import { ITeFi } from './external/ITeFi.sol';
import { StdTally } from './StdTally.sol';

contract TeFiTally is StdTally {
  ITeFi internal immutable _tefi;

  constructor(ITeFi tefi_) {
    _tefi = tefi_;
  }

  function _totalBalance(bytes memory) internal view override returns (uint256 totalBalance_) {
    return _tefi.asset().balanceOf(address(_tefi));
  }
}
