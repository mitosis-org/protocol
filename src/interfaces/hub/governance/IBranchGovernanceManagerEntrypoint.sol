// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IMessageRecipient } from '@hpl-v5/interfaces/IMessageRecipient.sol';

interface IBranchGovernanceManagerEntrypoint is IMessageRecipient {
  function dispatchGovernanceExecution(
    uint256 chainId,
    address[] calldata targets,
    bytes[] calldata data,
    uint256[] calldata values
  ) external;
}
