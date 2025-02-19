// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';
import { AccessControlEnumerableUpgradeable } from '@ozu-v5/access/extensions/AccessControlEnumerableUpgradeable.sol';
import { TimelockControllerUpgradeable } from '@ozu-v5/governance/TimelockControllerUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

contract Timelock is TimelockControllerUpgradeable, AccessControlEnumerableUpgradeable, UUPSUpgradeable {
  constructor() {
    _disableInitializers();
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(TimelockControllerUpgradeable, AccessControlEnumerableUpgradeable)
    returns (bool)
  {
    return TimelockControllerUpgradeable.supportsInterface(interfaceId)
      || AccessControlEnumerableUpgradeable.supportsInterface(interfaceId);
  }

  function _grantRole(bytes32 role, address account)
    internal
    override(AccessControlEnumerableUpgradeable, AccessControlUpgradeable)
    returns (bool)
  {
    return AccessControlEnumerableUpgradeable._grantRole(role, account);
  }

  function _revokeRole(bytes32 role, address account)
    internal
    override(AccessControlEnumerableUpgradeable, AccessControlUpgradeable)
    returns (bool)
  {
    return AccessControlEnumerableUpgradeable._revokeRole(role, account);
  }

  function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }
}
