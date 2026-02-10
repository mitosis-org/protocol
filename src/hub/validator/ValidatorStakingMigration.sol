// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { AccessControlEnumerableUpgradeable } from '@ozu/access/extensions/AccessControlEnumerableUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu/proxy/utils/UUPSUpgradeable.sol';
import { ReentrancyGuardUpgradeable } from '@ozu/utils/ReentrancyGuardUpgradeable.sol';

import { IValidatorStaking } from '../../interfaces/hub/validator/IValidatorStaking.sol';
import { IValidatorStakingMigration } from '../../interfaces/hub/validator/IValidatorStakingMigration.sol';
import { ITMITO } from '../../external/interfaces/ITMITO.sol';
import { StdError } from '../../lib/StdError.sol';

/// @title ValidatorStakingMigration
/// @notice Enables migration of staking between ValidatorStaking_MITO and ValidatorStaking_TMITO.
/// @dev Uses approveStakingOwnership and transferStakingOwnershipFrom.
///      Requires ValidatorStaking_TMITO owner to set this contract as migrationAgent for instant migration.
contract ValidatorStakingMigration is
  IValidatorStakingMigration,
  ReentrancyGuardUpgradeable,
  AccessControlEnumerableUpgradeable,
  UUPSUpgradeable
{
  IValidatorStaking public immutable tmitoValidatorStaking;
  IValidatorStaking public immutable mitoValidatorStaking;
  ITMITO public immutable tMITO;

  constructor(IValidatorStaking tmitoValidatorStaking_, IValidatorStaking mitoValidatorStaking_, ITMITO tMITO_) {
    _disableInitializers();
    tmitoValidatorStaking = tmitoValidatorStaking_;
    mitoValidatorStaking = mitoValidatorStaking_;
    tMITO = tMITO_;
  }

  function initialize(address admin) external initializer {
    __ReentrancyGuard_init();
    __AccessControlEnumerable_init();
    __UUPSUpgradeable_init();
    _grantRole(DEFAULT_ADMIN_ROLE, admin);
  }

  /// @notice Instant migration: TMITO -> MITO in a single tx (bypasses unstake cooldown).
  /// @dev Requires: 1) User approved this contract on tmitoValidatorStaking.approveStakingOwnership
  ///                2) ValidatorStaking_TMITO owner set this contract as migrationAgent
  /// @param valAddr Validator address
  /// @param amount Amount of TMITO staking to migrate
  /// @param recipient Address to receive MITO staking
  function migrateFromTMITOToMITO(address valAddr, uint256 amount, address recipient)
    external
    nonReentrant
    returns (uint256)
  {
    require(amount > 0, StdError.ZeroAmount());
    require(recipient != address(0), StdError.ZeroAddress('recipient'));
    require(tMITO.isLockupEnded(), ValidatorStakingMigration__LockupNotEnded());
    require(tmitoValidatorStaking.migrationAgent() == address(this), ValidatorStakingMigration__NotMigrationAgent());

    // 1. Transfer staking ownership from user to this contract
    tmitoValidatorStaking.transferStakingOwnershipFrom(valAddr, _msgSender(), address(this), amount);

    // 2. Request unstake (adds to queue)
    tmitoValidatorStaking.requestUnstake(valAddr, address(this), amount);

    // 3. Claim immediately, bypassing cooldown (requires migrationAgent role)
    uint256 tmitoAmount = tmitoValidatorStaking.claimUnstakeForMigration();

    // 4. Redeem TMITO to MITO
    uint256 balanceBefore = address(this).balance;
    tMITO.redeem(address(this), tmitoAmount);
    uint256 mitoAmount = address(this).balance - balanceBefore;

    // 5. Stake MITO in ValidatorStaking_MITO for recipient
    mitoValidatorStaking.stake{ value: mitoAmount }(valAddr, recipient, mitoAmount);

    emit InstantMigrationCompleted(_msgSender(), valAddr, recipient, mitoAmount);

    return mitoAmount;
  }

  function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }

  /// @dev Required to receive native MITO from tMITO.redeem()
  receive() external payable { }
}
