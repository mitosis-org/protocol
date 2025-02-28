// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AccessControlEnumerableUpgradeable } from '@ozu-v5/access/extensions/AccessControlEnumerableUpgradeable.sol';
import { TimelockControllerUpgradeable } from '@ozu-v5/governance/TimelockControllerUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { StdError } from '../../lib/StdError.sol';

contract BranchTimelock is TimelockControllerUpgradeable, UUPSUpgradeable {
  // ============================ NOTE: INITIALIZATION FUNCTIONS ============================ //

  constructor() {
    _disableInitializers();
  }

  function initialize(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
    public
    override
    initializer
  {
    __UUPSUpgradeable_init();
    __TimelockController_init(minDelay, proposers, executors, admin);
  }

  function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }
}
