// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IMessageRecipient } from '@hpl-v5/interfaces/IMessageRecipient.sol';

import { Conv } from '../lib/Conv.sol';
import { StdError } from '../lib/StdError.sol';
import '../message/Message.sol';
import { GovernanceExecutor } from './GovernanceExecutor.sol';

contract GovernanceExecutorEntrypoint is IMessageRecipient {
  using Message for *;
  using Conv for *;

  GovernanceExecutor internal immutable _governanceExecutor;
  uint32 internal immutable _mitosisDomain;
  bytes32 internal immutable _mitosisAddr;

  //=========== NOTE: HANDLER FUNCTIONS ===========//

  function _handle(uint32 origin, bytes32 sender, bytes calldata msg_) internal override {
    require(origin == _mitosisDomain && sender == _mitosisAddr, StdError.Unauthorized());

    MsgType msgType = msg_.msgType();

    if (msgType == MsgType.MsgDispatchMITOGovernanceExecution) {
      MsgDispatchMITOGovernanceExecution memory decoded = msg_.decodeDispatchMITOGovernanceExecution();
      _governanceExecutor.execute(_convertBytes32ArrayToAddressArray(decoded.targets), decoded.data, decoded.value);
    }
  }

  function _convertBytes32ArrayToAddressArray(bytes32[] calldata targets)
    internal
    returns (address[] calldata addressed)
  {
    addressed = new address[](targets.length);
    for (uint256 i = 0; i < targets.length; i++) {
      addressed[i] = targets[i].toAddress();
    }
  }
}
