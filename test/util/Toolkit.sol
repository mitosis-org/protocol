// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from '@std/Test.sol';

import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';

import { Pausable } from '../../src/lib/Pausable.sol';
import { StdError } from '../../src/lib/StdError.sol';

contract Toolkit is Test {
  // OwnableUpgradeable

  function _errOwnableUnauthorizedAccount(address sender) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, sender);
  }

  // Pausable

  function _errPaused(bytes4 sig) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(Pausable.Pausable__Paused.selector, sig);
  }

  // StdError

  function _errUnauthorized() internal pure returns (bytes memory) {
    return abi.encodeWithSelector(StdError.Unauthorized.selector);
  }

  function _errZeroToAddress() internal pure returns (bytes memory) {
    return abi.encodeWithSelector(StdError.ZeroAddress.selector, 'to');
  }

  function _errZeroAmount() internal pure returns (bytes memory) {
    return abi.encodeWithSelector(StdError.ZeroAmount.selector);
  }

  function _errInvalidAddress(string memory context) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(StdError.InvalidAddress.selector, context);
  }

  function _errInvalidParameter(string memory context) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(StdError.InvalidParameter.selector, context);
  }

  function _errNotFound(string memory context) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(StdError.NotFound.selector, context);
  }
}
