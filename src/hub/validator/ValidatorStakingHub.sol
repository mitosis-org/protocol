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
    mapping(address valAddr => LibCheckpoint.TraceTWAB) totalStaked;
    mapping(address valAddr => mapping(address staker => LibCheckpoint.TraceTWAB)) staked;
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

  function staked(address valAddr, address staker) external view returns (uint256) {
    require(staker != address(0), StdError.InvalidParameter('staker'));
    return _staked(_getStorageV1(), valAddr, staker, Time.timestamp());
  }

  function stakedAt(address valAddr, address staker, uint48 timestamp) external view returns (uint256) {
    require(staker != address(0), StdError.InvalidParameter('staker'));
    require(timestamp > 0, StdError.InvalidParameter('timestamp'));
    StorageV1 storage $ = _getStorageV1();
    return _staked($, valAddr, staker, timestamp);
  }

  function stakedTWAB(address valAddr, address staker) external view returns (uint256) {
    require(staker != address(0), StdError.InvalidParameter('staker'));
    return _stakedTWAB(_getStorageV1(), valAddr, staker, Time.timestamp());
  }

  function stakedTWABAt(address valAddr, address staker, uint48 timestamp) external view returns (uint256) {
    require(staker != address(0), StdError.InvalidParameter('staker'));
    require(timestamp > 0, StdError.InvalidParameter('timestamp'));
    return _stakedTWAB(_getStorageV1(), valAddr, staker, timestamp);
  }

  function totalStaked(address valAddr) external view returns (uint256) {
    return _totalStaked(_getStorageV1(), valAddr, Time.timestamp());
  }

  function totalStakedAt(address valAddr, uint48 timestamp) external view returns (uint256) {
    require(timestamp > 0, StdError.InvalidParameter('timestamp'));
    return _totalStaked(_getStorageV1(), valAddr, timestamp);
  }

  function totalStakedTWAB(address valAddr) external view returns (uint256) {
    return _totalStakedTWAB(_getStorageV1(), valAddr, Time.timestamp());
  }

  function totalStakedTWABAt(address valAddr, uint48 timestamp) external view returns (uint256) {
    require(timestamp > 0, StdError.InvalidParameter('timestamp'));
    return _totalStakedTWAB(_getStorageV1(), valAddr, timestamp);
  }

  function addNotifier(address notifier) external onlyOwner {
    // TODO(eddy): We need to add calculation logic for each notifier
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

  function _staked(StorageV1 storage $, address valAddr, address staker, uint48 timestamp)
    internal
    view
    returns (uint256)
  {
    LibCheckpoint.TraceTWAB storage history = $.staked[valAddr][staker];
    if (history.len() == 0) return 0;

    LibCheckpoint.TWABCheckpoint memory last = history.search(timestamp);
    return last.amount;
  }

  function _stakedTWAB(StorageV1 storage $, address valAddr, address staker, uint48 timestamp)
    internal
    view
    returns (uint256)
  {
    LibCheckpoint.TraceTWAB storage history = $.staked[valAddr][staker];
    if (history.len() == 0) return 0;

    LibCheckpoint.TWABCheckpoint memory last = history.search(timestamp);
    return (last.amount * (timestamp - last.lastUpdate));
  }

  function _totalStaked(StorageV1 storage $, address valAddr, uint48 timestamp) internal view returns (uint256) {
    LibCheckpoint.TraceTWAB storage history = $.totalStaked[valAddr];
    if (history.len() == 0) return 0;

    LibCheckpoint.TWABCheckpoint memory last = history.search(timestamp);
    return last.amount;
  }

  function _totalStakedTWAB(StorageV1 storage $, address valAddr, uint48 timestamp) internal view returns (uint256) {
    LibCheckpoint.TraceTWAB storage history = $.totalStaked[valAddr];
    if (history.len() == 0) return 0;

    LibCheckpoint.TWABCheckpoint memory last = history.search(timestamp);
    return last.twab + (last.amount * (timestamp - last.lastUpdate));
  }

  function _stake(StorageV1 storage $, address valAddr, address staker, uint256 amount) internal {
    uint48 now_ = Time.timestamp();
    $.staked[valAddr][staker].push(amount, now_, LibCheckpoint.add);
    $.stakerTotal[staker].push(amount, now_, LibCheckpoint.add);
    $.totalStaked[valAddr].push(amount, now_, LibCheckpoint.add);

    _updateExtraVotingPower($, valAddr);
  }

  function _unstake(StorageV1 storage $, address valAddr, address staker, uint256 amount) internal {
    uint48 now_ = Time.timestamp();
    $.staked[valAddr][staker].push(amount, now_, LibCheckpoint.sub);
    $.stakerTotal[staker].push(amount, now_, LibCheckpoint.sub);
    $.totalStaked[valAddr].push(amount, now_, LibCheckpoint.sub);

    _updateExtraVotingPower($, valAddr);
  }

  function _updateExtraVotingPower(StorageV1 storage $, address valAddr) internal {
    _entrypoint.updateExtraVotingPower(
      _manager.validatorInfo(valAddr).valKey, //
      $.totalStaked[valAddr].last().amount
    );
  }
}
