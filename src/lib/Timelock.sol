// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';
import { AccessControlEnumerableUpgradeable } from '@ozu-v5/access/extensions/AccessControlEnumerableUpgradeable.sol';
import { TimelockControllerUpgradeable } from '@ozu-v5/governance/TimelockControllerUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { Pausable } from './Pausable.sol';

contract Timelock is TimelockControllerUpgradeable, AccessControlEnumerableUpgradeable, UUPSUpgradeable, Pausable {
  constructor() {
    _disableInitializers();
  }

  function initialize(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
    public
    override
    initializer
  {
    __Pausable_init();
    __UUPSUpgradeable_init();
    __TimelockController_init(minDelay, proposers, executors, admin);
    __AccessControlEnumerable_init();
  }

  function execute(address target, uint256 value, bytes calldata payload, bytes32 predecessor, bytes32 salt)
    public
    payable
    override
    notPaused
    onlyRoleOrOpenRole(EXECUTOR_ROLE)
  {
    super.execute(target, value, payload, predecessor, salt);
  }

  function executeBatch(
    address[] calldata targets,
    uint256[] calldata values,
    bytes[] calldata payloads,
    bytes32 predecessor,
    bytes32 salt
  ) public payable override notPaused onlyRoleOrOpenRole(EXECUTOR_ROLE) {
    super.executeBatch(targets, values, payloads, predecessor, salt);
  }

  function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _pause();
  }

  function pause(bytes4 sig) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _pause(sig);
  }

  function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _unpause();
  }

  function unpause(bytes4 sig) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _unpause(sig);
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
