// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from '@std/Test.sol';

contract Toolkit is Test {
  function _addr(string memory input) internal pure virtual returns (address) {
    return vm.addr(_key(input));
  }

  function _key(string memory input) internal pure virtual returns (uint256) {
    return uint256(keccak256(abi.encodePacked(input)));
  }
}
