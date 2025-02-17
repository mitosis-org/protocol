// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';

import { GasRouter } from '@hpl-v5/client/GasRouter.sol';

import { IGovernanceExecutorEntrypoint } from '../interfaces/branch/IGovernanceExecutorEntrypoint.sol';
import { Conv } from '../lib/Conv.sol';
import { StdError } from '../lib/StdError.sol';
import '../message/Message.sol';
import { GovernanceExecutor } from './GovernanceExecutor.sol';

contract GovernanceExecutorEntrypoint is IGovernanceExecutorEntrypoint, GasRouter, Ownable2StepUpgradeable {
  using Message for *;
  using Conv for *;

  GovernanceExecutor internal immutable _governanceExecutor;
  uint32 internal immutable _mitosisDomain;
  bytes32 internal immutable _mitosisAddr; // Hub.BranchGovernanceManagerEntrypoint

  constructor(address mailbox, address governanceExecutor_, uint32 mitosisDomain_, bytes32 mitosisAddr_)
    GasRouter(mailbox)
    initializer
  {
    _governanceExecutor = GovernanceExecutor(governanceExecutor_);
    _mitosisDomain = mitosisDomain_;
    _mitosisAddr = mitosisAddr_;
  }

  function initialize(address owner_, address hook, address ism) public initializer {
    _MailboxClient_initialize(hook, ism, owner_);
    __Ownable2Step_init();
    _transferOwnership(owner_);

    _enrollRemoteRouter(_mitosisDomain, _mitosisAddr);
  }

  //=========== NOTE: HANDLER FUNCTIONS ===========//

  function _handle(uint32 origin, bytes32 sender, bytes calldata msg_) internal override {
    require(origin == _mitosisDomain && sender == _mitosisAddr, StdError.Unauthorized());

    MsgType msgType = msg_.msgType();

    if (msgType == MsgType.MsgDispatchMITOGovernanceExecution) {
      MsgDispatchMITOGovernanceExecution memory decoded = msg_.decodeDispatchMITOGovernanceExecution();
      _governanceExecutor.execute(_convertBytes32ArrayToAddressArray(decoded.targets), decoded.data, decoded.values);
    }
  }

  function _convertBytes32ArrayToAddressArray(bytes32[] memory targets)
    internal
    pure
    returns (address[] memory addressed)
  {
    addressed = new address[](targets.length);
    for (uint256 i = 0; i < targets.length; i++) {
      addressed[i] = targets[i].toAddress();
    }
  }

  //=========== NOTE: OwnableUpgradeable & Ownable2StepUpgradeable

  function transferOwnership(address owner) public override(Ownable2StepUpgradeable, OwnableUpgradeable) {
    Ownable2StepUpgradeable.transferOwnership(owner);
  }

  function _transferOwnership(address owner) internal override(Ownable2StepUpgradeable, OwnableUpgradeable) {
    Ownable2StepUpgradeable._transferOwnership(owner);
  }
}
