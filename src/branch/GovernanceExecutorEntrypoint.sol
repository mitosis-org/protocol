// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IGovernanceExecutorEntrypoint } from '../interfaces/branch/IGovernanceExecutorEntrypoint.sol';
import { Conv } from '../lib/Conv.sol';
import { StdError } from '../lib/StdError.sol';
import '../message/Message.sol';
import { GovernanceExecutor } from './GovernanceExecutor.sol';

// Removal after discussion: Since there will be no Branch -> Hub cases, it does not inherit from Router.
contract GovernanceExecutorEntrypoint is IGovernanceExecutorEntrypoint, Ownable2StepUpgradeable {
  using Message for *;
  using Conv for *;

  GovernanceExecutor internal immutable _governanceExecutor;
  uint32 internal immutable _mitosisDomain;
  bytes32 internal immutable _mitosisAddr; // Hub.BranchGovernanceManagerEntrypoint

  constructor(address governanceExecutor_, uint32 mitosisDomain_, bytes32 mitosisAddr_) initializer {
    _governanceExecutor = GovernanceExecutor(governanceExecutor_);
    _mitosisDomain = mitosisDomain_;
    _mitosisAddr = mitosisAddr_;
  }

  function initialize(address owner_) public initializer {
    __Ownable2Step_init();
    _transferOwnership(owner_);
  }

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
