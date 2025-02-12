// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from '@std/Test.sol';

import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { ERC1967Utils } from '@oz-v5/proxy/ERC1967/ERC1967Utils.sol';

import { Pausable } from '../../src/lib/Pausable.sol';
import { StdError } from '../../src/lib/StdError.sol';

contract Toolkit is Test {
  using SafeCast for uint256;

  function _erc1967Impl(address target) internal view returns (address) {
    return address(uint160(uint256(vm.load(target, ERC1967Utils.IMPLEMENTATION_SLOT))));
  }

  function _erc1967Admin(address target) internal view returns (address) {
    return address(uint160(uint256(vm.load(target, ERC1967Utils.ADMIN_SLOT))));
  }

  function _erc1967Beacon(address target) internal view returns (address) {
    return address(uint160(uint256(vm.load(target, ERC1967Utils.BEACON_SLOT))));
  }

  function _now() internal view returns (uint256) {
    return block.timestamp;
  }

  function _now48() internal view returns (uint48) {
    return block.timestamp.toUint48();
  }

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
