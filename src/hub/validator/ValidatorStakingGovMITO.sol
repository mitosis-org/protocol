// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Time } from '@oz-v5/utils/types/Time.sol';

import { VotesUpgradeable } from '@ozu-v5/governance/utils/VotesUpgradeable.sol';

import { IValidatorManager } from '../../interfaces/hub/validator/IValidatorManager.sol';
import { IValidatorStakingHub } from '../../interfaces/hub/validator/IValidatorStakingHub.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';
import { ValidatorStaking } from './ValidatorStaking.sol';

contract ValidatorStakingGovMITO is ValidatorStaking, VotesUpgradeable {
  using ERC7201Utils for string;

  // ========= begin storage ========= //

  struct GovMITOStorageV1 {
    address delegationManager;
  }

  string private constant _NAMESPACE = 'mitosis.storage.ValidatorStakingGovMITO.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getGovMITOStorageV1() internal view returns (GovMITOStorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // ========= end storage ========= //

  event DelegationManagerSet(address indexed previous, address indexed next);

  error ValidatorStakingGovMITO__NonTransferable();

  constructor(address baseAsset_, IValidatorManager manager_, IValidatorStakingHub hub_)
    ValidatorStaking(baseAsset_, manager_, hub_)
  {
    _disableInitializers();
  }

  function initialize(
    address initialOwner,
    uint256 initialMinStakingAmount,
    uint256 initialMinUnstakingAmount,
    uint48 unstakeCooldown_,
    uint48 redelegationCooldown_
  ) public override initializer {
    super.initialize(
      initialOwner, //
      initialMinStakingAmount,
      initialMinUnstakingAmount,
      unstakeCooldown_,
      redelegationCooldown_
    );

    __Votes_init();
  }

  function delegationManager() public view returns (address) {
    return _getGovMITOStorageV1().delegationManager;
  }

  function clock() public view override returns (uint48) {
    return Time.timestamp();
  }

  function CLOCK_MODE() public view override returns (string memory) {
    // Check that the clock was not modified
    require(clock() == Time.timestamp(), ERC6372InconsistentClock());
    return 'mode=timestamp';
  }

  /// @dev Disabled: make only the delegation manager can delegate
  function delegate(address) public pure override {
    revert StdError.NotSupported();
  }

  /// @dev Disabled: make only the delegation manager can delegate
  function delegateBySig(address, uint256, uint256, uint8, bytes32, bytes32) public pure override {
    revert StdError.NotSupported();
  }

  /// @dev Only the delegation manager can perform delegate
  function sudoDelegate(address account, address delegatee) public {
    require(_getGovMITOStorageV1().delegationManager == _msgSender(), StdError.Unauthorized());

    _delegate(account, delegatee);
  }

  /// @dev Only the owner can set the delegation manager
  function setDelegationManager(address delegationManager_) public onlyOwner {
    address previous = _getGovMITOStorageV1().delegationManager;
    _getGovMITOStorageV1().delegationManager = delegationManager_;

    emit DelegationManagerSet(previous, delegationManager_);
  }

  function _getVotingUnits(address account) internal view override returns (uint256) {
    uint48 now_ = clock();
    return stakerTotal(account, now_) + unstakingTotal(account, now_);
  }

  /// @dev Mints voting units to the recipient. No need to care about the validator
  function _stake(StorageV1 storage $, address valAddr, address recipient, uint256 amount)
    internal
    override
    returns (uint256)
  {
    require(recipient == _msgSender(), ValidatorStakingGovMITO__NonTransferable());

    // mint the voting units
    _transferVotingUnits(address(0), recipient, amount);

    return super._stake($, valAddr, recipient, amount);
  }

  /// @dev Prevent the other users to receive unstaked tokens. Otherwise, users can perform transfer tokens to the others.
  function _requestUnstake(StorageV1 storage $, address valAddr, address receiver, uint256 amount)
    internal
    override
    returns (uint256)
  {
    require(receiver == _msgSender(), ValidatorStakingGovMITO__NonTransferable());
    return super._requestUnstake($, valAddr, receiver, amount);
  }

  /// @dev Burns the voting units from the recipient
  function _claimUnstake(StorageV1 storage $, address valAddr, address receiver) internal override returns (uint256) {
    uint256 claimed = super._claimUnstake($, valAddr, receiver);

    // burn the voting units
    _transferVotingUnits(receiver, address(0), claimed);

    return claimed;
  }
}
