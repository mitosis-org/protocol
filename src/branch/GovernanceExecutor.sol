// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Address } from '@oz-v5/utils/Address.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IGovernanceExecutor } from '../interfaces/branch/IGovernanceExecutor.sol';
import { Pausable } from '../lib/Pausable.sol';
import { StdError } from '../lib/StdError.sol';
import { GovernanceExecutorStorageV1 } from './GovernanceExecutorStorageV1.sol';

contract GovernanceExecutor is IGovernanceExecutor, GovernanceExecutorStorageV1, Pausable, Ownable2StepUpgradeable {
  using Address for address;

  function execute(address[] calldata targets, bytes[] calldata data, uint256[] calldata values) external {
    require(targets.length == data.length, StdError.InvalidParameter('data'));
    require(targets.length == values.length, StdError.InvalidParameter('values'));

    _assertOnlyGovernanceExecutorEntrypoint(_getStorageV1());

    bytes[] memory result = new bytes[](targets.length);
    for (uint256 i = 0; i < targets.length; i++) {
      result[i] = targets[i].functionCallWithValue(data[i], values[i]);
    }

    emit ExecutionDispatched(targets, data, values, result);
  }

  function entrypoint() external view returns (address) {
    return address(_getStorageV1().entrypoint);
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  function _assertOnlyGovernanceExecutorEntrypoint(StorageV1 storage $) internal view {
    require(_msgSender() == address($.entrypoint), StdError.Unauthorized());
  }
}
