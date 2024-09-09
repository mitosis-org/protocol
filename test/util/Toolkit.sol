// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from '@std/Test.sol';

import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';

import { StdError } from '../../src/lib/StdError.sol';

contract Toolkit is Test {
  function _errOwnableUnauthorizedAccount(address sender) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, sender);
  }

  function _errUnauthorized() internal pure returns (bytes memory) {
    return abi.encodeWithSelector(StdError.Unauthorized.selector);
  }
}
