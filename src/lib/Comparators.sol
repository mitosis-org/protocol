// SPDX-License-Identifier: MIT

// Copied from OpenZeppelin temporarily. This file will be removed after next release of OpenZeppelin Contracts.

pragma solidity ^0.8.20;

library Comparators {
  function lt(uint256 a, uint256 b) internal pure returns (bool) {
    return a < b;
  }

  function gt(uint256 a, uint256 b) internal pure returns (bool) {
    return a > b;
  }
}
