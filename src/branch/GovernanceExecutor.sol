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

    _assertAuthroizedCaller(_getStorageV1());

    bytes[] memory result = new bytes[](targets.length);
    for (uint256 i = 0; i < targets.length; i++) {
      result[i] = targets[i].functionCallWithValue(data[i], values[i]);
    }

    emit ExecutionDispatched(targets, data, values, result);
  }

  function entrypoint() external view returns (address) {
    return address(_getStorageV1().entrypoint);
  }

  function setManager(address manager) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    require(!$.managers[manager], StdError.InvalidParameter('manager'));
    _getStorageV1().managers[manager] = true;
    emit ManagerSet(manager);
  }

  function unsetManager(address manager) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    require($.managers[manager], StdError.InvalidParameter('manager'));
    _getStorageV1().managers[manager] = false;
    emit ManagerUnset(manager);
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  function _assertAuthroizedCaller(StorageV1 storage $) internal view {
    address msgSender = _msgSender();
    require($.managers[msgSender] || msgSender == address($.entrypoint), StdError.Unauthorized());
  }
}
