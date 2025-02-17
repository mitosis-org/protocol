// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Address } from '@oz-v5/utils/Address.sol';

import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { IGovernanceExecutor } from '../interfaces/branch/IGovernanceExecutor.sol';
import { IGovernanceExecutorEntrypoint } from '../interfaces/branch/IGovernanceExecutorEntrypoint.sol';
import { Pausable } from '../lib/Pausable.sol';
import { StdError } from '../lib/StdError.sol';
import { GovernanceExecutorStorageV1 } from './GovernanceExecutorStorageV1.sol';

contract GovernanceExecutor is
  IGovernanceExecutor,
  GovernanceExecutorStorageV1,
  Pausable,
  UUPSUpgradeable,
  AccessControlUpgradeable
{
  using Address for address;

  /// @notice Role for manager (keccak256("EXECUTOR_ROLE"))
  bytes32 public constant EXECUTOR_ROLE = 0xd8aa0f3194971a2a116679f7c2090f6939c8d4e01a2a8d7e41d55e5351469e63;

  constructor() {
    _disableInitializers();
  }

  function initialize(address[] memory executors) public initializer {
    __Pausable_init();
    __AccessControl_init();

    _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
    _grantRole(DEFAULT_ADMIN_ROLE, address(this));

    for (uint256 i = 0; i < executors.length; i++) {
      _grantRole(MANAGER_ROLE, executors[i]);
    }
  }

  function execute(address[] calldata targets, bytes[] calldata data, uint256[] calldata values) external {
    require(targets.length == data.length, StdError.InvalidParameter('data'));
    require(targets.length == values.length, StdError.InvalidParameter('values'));

    require(hasRole(MANAGER_ROLE, _msgSender()), StdError.Unauthorized());

    bytes[] memory result = new bytes[](targets.length);
    for (uint256 i = 0; i < targets.length; i++) {
      result[i] = targets[i].functionCallWithValue(data[i], values[i]);
    }

    emit ExecutionDispatched(targets, data, values, result);
  }

  function entrypoint() external view returns (address) {
    return address(_getStorageV1().entrypoint);
  }

  function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _pause();
  }

  function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _unpause();
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }
}
