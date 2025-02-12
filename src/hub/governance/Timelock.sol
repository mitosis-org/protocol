// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { TimelockControllerUpgradeable } from '@ozu-v5/governance/TimelockControllerUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

contract Timelock is UUPSUpgradeable, TimelockControllerUpgradeable {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }
}
