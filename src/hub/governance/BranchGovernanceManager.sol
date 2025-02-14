// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { Address } from '@oz-v5/utils/Address.sol';

import { IBranchGovernanceManager } from '../../interfaces/hub/governance/IBranchGovernanceManager.sol';
import { IBranchGovernanceManagerEntrypoint } from
  '../../interfaces/hub/governance/IBranchGovernanceManagerEntrypoint.sol';
import { Pausable } from '../../lib/Pausable.sol';
import { StdError } from '../../lib/StdError.sol';
import { BranchGovernanceManagerStorageV1 } from './BranchGovernanceManagerStorageV1.sol';

contract BranchGovernanceManager is
  IBranchGovernanceManager,
  BranchGovernanceManagerStorageV1,
  Pausable,
  Ownable2StepUpgradeable
{
  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_, address branchGovernanceManagerEntrypoint_) public initializer {
    __Pausable_init();
    __Ownable2Step_init();
    _transferOwnership(owner_);
    _getStorageV1().entrypoint = IBranchGovernanceManagerEntrypoint(branchGovernanceManagerEntrypoint_);
  }

  function isManager(address manager) public view returns (bool) {
    return _getStorageV1().managers[manager];
  }

  function dispatchExecution(
    uint256 chainId,
    address[] calldata targets,
    bytes[] calldata data,
    uint256[] calldata values
  ) external {
    StorageV1 storage $ = _getStorageV1();
    _assertExecutable($);
    $.entrypoint.dispatchGovernanceExecution(chainId, targets, data, values);
  }

  function setMITOGovernance(address mitoGovernance_) external {
    StorageV1 storage $ = _getStorageV1();
    _assertExecutable($);

    address prev = $.mitoGovernance;
    $.mitoGovernance = mitoGovernance_;
    emit MITOGovernanceSet(prev, mitoGovernance_);
  }

  function setManager(address manager) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    if ($.managers[manager]) {
      return;
    }
    _getStorageV1().managers[manager] = true;
    emit ManagerSet(manager);
  }

  function finalizeManagerPhase() external {
    StorageV1 storage $ = _getStorageV1();
    _assertExecutable($);
    $.managerPhaseOver = true;
    emit ManagerPhaseOver();
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  function _assertExecutable(StorageV1 storage $) internal view {
    address msgSender = _msgSender();
    if (!$.managerPhaseOver) {
      require($.managers[msgSender] || msgSender == $.mitoGovernance, StdError.Unauthorized());
    }
    require(msgSender == $.mitoGovernance, StdError.Unauthorized());
  }

  function _assertOnlyMITOGovernance(StorageV1 storage $) internal view {
    require(_msgSender() == $.mitoGovernance, StdError.Unauthorized());
  }
}
