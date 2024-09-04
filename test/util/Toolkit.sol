// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from '@std/Test.sol';

import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';

import { StdError } from '../../src/lib/StdError.sol';

contract Toolkit is Test {
  function _addr(string memory input) internal pure virtual returns (address) {
    return vm.addr(_key(input));
  }

  function _key(string memory input) internal pure virtual returns (uint256) {
    return uint256(keccak256(abi.encodePacked(input)));
  }

  function _errOwnableUnauthorizedAccount(address sender) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, sender);
  }

  function _errUnauthorized() internal pure returns (bytes memory) {
    return abi.encodeWithSelector(StdError.Unauthorized.selector);
  }
}
