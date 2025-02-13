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

  function dispatchExecution(
    uint256 chainId,
    address[] calldata targets,
    bytes[] calldata data,
    uint256[] calldata valuess
  ) external {
    StorageV1 storage $ = _getStorageV1();
    _assertOnlyMITOGovernance($);
    $.entrypoint.dispatchGovernanceExecution(chainId, targets, data, values);
  }

  function setMITOGovernance(address mitoGovernance_) external onlyOwner {
    _getStorageV1().mitoGovernance = mitoGovernance_;
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  function _assertOnlyMITOGovernance(StorageV1 storage $) internal {
    require(_msgSender() == $.mitoGovernance, StdError.Unauthorized());
  }
}
