// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Address } from '@oz-v5/utils/Address.sol';

import { BranchGovernanceManagerEntrypoint } from './BranchGovernanceManagerEntrypoint.sol';

contract BranchGovernanceManager {
  address _mitoGovernance;
  BranchGovernanceManagerEntrypoint _entrypoint;

  function dispatchExecution(
    uint256 chainId,
    address[] calldata targets,
    bytes[] calldata data,
    uint256[] calldata valuess
  ) external {
    _assertOnlyMITOGovernance();
    _entrypoint.dispatchGovernanceExecution(chainId, targets, data, values);
  }

  function _assertOnlyMITOGovernance() internal {
    require(msg.sender == _mitoGovernance, 'Auth');
  }
}
