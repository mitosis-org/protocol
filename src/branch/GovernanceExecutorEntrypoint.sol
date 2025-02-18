// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { GasRouter } from '@hpl-v5/client/GasRouter.sol';

import { IGovernanceExecutorEntrypoint } from '../interfaces/branch/IGovernanceExecutorEntrypoint.sol';
import { Conv } from '../lib/Conv.sol';
import { StdError } from '../lib/StdError.sol';
import '../message/Message.sol';
import { GovernanceExecutor } from './GovernanceExecutor.sol';

contract GovernanceExecutorEntrypoint is
  IGovernanceExecutorEntrypoint,
  GasRouter,
  UUPSUpgradeable,
  AccessControlUpgradeable
{
  using Message for *;
  using Conv for *;

  GovernanceExecutor internal immutable _governanceExecutor;
  uint32 internal immutable _mitosisDomain;
  bytes32 internal immutable _mitosisAddr; // Hub.BranchGovernanceEntrypoint

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
    __UUPSUpgradeable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, owner_);

    _enrollRemoteRouter(_mitosisDomain, _mitosisAddr);
  }

  //=========== NOTE: HANDLER FUNCTIONS ===========//

  function _handle(uint32 origin, bytes32 sender, bytes calldata msg_) internal override {
    require(origin == _mitosisDomain && sender == _mitosisAddr, StdError.Unauthorized());

    MsgType msgType = msg_.msgType();

    if (msgType == MsgType.MsgDispatchGovernanceExecution) {
      MsgDispatchGovernanceExecution memory decoded = msg_.decodeDispatchGovernanceExecution();
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

  //=========== NOTE: Internal methods ===========//

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }
}
