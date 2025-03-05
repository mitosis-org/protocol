// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { Time } from '@oz-v5/utils/types/Time.sol';

import { IConsensusValidatorEntrypoint } from '../../interfaces/hub/consensus-layer/IConsensusValidatorEntrypoint.sol';
import { IValidatorManager } from '../../interfaces/hub/validator/IValidatorManager.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { LibCheckpoint } from '../../lib/LibCheckpoint.sol';
import { StdError } from '../../lib/StdError.sol';

contract ValidatorStakingHubStorage {
  using ERC7201Utils for string;

  struct StorageV1 {
    mapping(address notifier => bool) notifiers;
    mapping(address staker => LibCheckpoint.TraceTWAB) stakerTotal;
    mapping(address valAddr => LibCheckpoint.TraceTWAB) validatorTotal;
    mapping(address valAddr => mapping(address staker => LibCheckpoint.TraceTWAB)) validatorStakerTotal;
  }

  string private constant _NAMESPACE = 'mitosis.storage.ValidatorStakingHubStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}

contract ValidatorStakingHub is ValidatorStakingHubStorage, Ownable2StepUpgradeable {
  using LibCheckpoint for LibCheckpoint.TraceTWAB;

  IValidatorManager private immutable _manager;
  IConsensusValidatorEntrypoint private immutable _entrypoint;

  constructor(IConsensusValidatorEntrypoint entrypoint_, IValidatorManager manager_) {
    _disableInitializers();

    _manager = manager_;
    _entrypoint = entrypoint_;
  }

  function initialize(address initialOwner) external initializer {
    __Ownable2Step_init();
    __Ownable_init(initialOwner);
  }

  function manager() public view returns (IValidatorManager) {
    return _manager;
  }

  function entrypoint() public view returns (IConsensusValidatorEntrypoint) {
    return _entrypoint;
  }

  function isNotifier(address notifier) external view returns (bool) {
    return _getStorageV1().notifiers[notifier];
  }

  function stakerTotal(address staker, uint48 timestamp) external view returns (uint256) {
    return _getStorageV1().stakerTotal[staker].findAmount(timestamp);
  }

  function stakerTotalTWAB(address staker, uint48 timestamp) external view returns (uint256) {
    return _getStorageV1().stakerTotal[staker].findTWAB(timestamp);
  }

  function validatorTotal(address valAddr, uint48 timestamp) external view returns (uint256) {
    return _getStorageV1().validatorTotal[valAddr].findAmount(timestamp);
  }

  function validatorTotalTWAB(address valAddr, uint48 timestamp) external view returns (uint256) {
    return _getStorageV1().validatorTotal[valAddr].findTWAB(timestamp);
  }

  function validatorStakerTotal(address valAddr, address staker, uint48 timestamp) external view returns (uint256) {
    return _getStorageV1().validatorStakerTotal[valAddr][staker].findAmount(timestamp);
  }

  function validatorStakerTotalTWAB(address valAddr, address staker, uint48 timestamp) external view returns (uint256) {
    return _getStorageV1().validatorStakerTotal[valAddr][staker].findTWAB(timestamp);
  }

  function addNotifier(address notifier) external onlyOwner {
    // TODO(eddy): Probably we need to add calculation logic for each notifier
    StorageV1 storage $ = _getStorageV1();
    $.notifiers[notifier] = true;
  }

  function removeNotifier(address notifier) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    $.notifiers[notifier] = false;
  }

  function notifyStake(address valAddr, address staker, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();
    require($.notifiers[_msgSender()], StdError.Unauthorized());

    _stake($, valAddr, staker, amount);
  }

  function notifyUnstake(address valAddr, address staker, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();
    require($.notifiers[_msgSender()], StdError.Unauthorized());

    _unstake($, valAddr, staker, amount);
  }

  function notifyRedelegation(address fromValAddr, address toValAddr, address staker, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();
    require($.notifiers[_msgSender()], StdError.Unauthorized());

    _unstake($, fromValAddr, staker, amount);
    _stake($, toValAddr, staker, amount);
  }

  // ===================================== INTERNAL FUNCTIONS ===================================== //

  function _stake(StorageV1 storage $, address valAddr, address staker, uint256 amount) internal {
    uint48 now_ = Time.timestamp();

    $.stakerTotal[staker].push(amount, now_, LibCheckpoint.add);
    $.validatorTotal[valAddr].push(amount, now_, LibCheckpoint.add);
    $.validatorStakerTotal[valAddr][staker].push(amount, now_, LibCheckpoint.add);

    _updateExtraVotingPower($, valAddr);
  }

  function _unstake(StorageV1 storage $, address valAddr, address staker, uint256 amount) internal {
    uint48 now_ = Time.timestamp();

    $.stakerTotal[staker].push(amount, now_, LibCheckpoint.sub);
    $.validatorTotal[valAddr].push(amount, now_, LibCheckpoint.sub);
    $.validatorStakerTotal[valAddr][staker].push(amount, now_, LibCheckpoint.sub);

    _updateExtraVotingPower($, valAddr);
  }

  function _updateExtraVotingPower(StorageV1 storage $, address valAddr) internal {
    _entrypoint.updateExtraVotingPower(
      _manager.validatorInfo(valAddr).valKey, //
      $.validatorTotal[valAddr].last().amount
    );
  }
}
