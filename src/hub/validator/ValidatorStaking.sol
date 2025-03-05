// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { SafeTransferLib } from '@solady/utils/SafeTransferLib.sol';

import { IConsensusValidatorEntrypoint } from '../../interfaces/hub/consensus-layer/IConsensusValidatorEntrypoint.sol';
import { IEpochFeeder } from '../../interfaces/hub/validator/IEpochFeeder.sol';
import { IValidatorManager } from '../../interfaces/hub/validator/IValidatorManager.sol';
import { IValidatorStaking } from '../../interfaces/hub/validator/IValidatorStaking.sol';
import { IValidatorStakingHub } from '../../interfaces/hub/validator/IValidatorStakingHub.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { LibRedeemQueue } from '../../lib/LibRedeemQueue.sol';
import { StdError } from '../../lib/StdError.sol';

contract ValidatorStakingStorageV1 {
  using ERC7201Utils for string;

  struct StorageV1 {
    uint128 totalStaked;
    uint128 totalUnstaking;
    uint48 unstakeCooldown;
    uint48 redelegationCooldown;
    uint160 padding; // FIXME(eddy): remove this or add a new field
    mapping(address staker => uint256) lastRedelegationTime;
    mapping(address valAddr => LibRedeemQueue.Queue) unstakeQueue;
  }

  string private constant _NAMESPACE = 'mitosis.storage.ValidatorStakingStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}

contract ValidatorStaking is IValidatorStaking, ValidatorStakingStorageV1, Ownable2StepUpgradeable, UUPSUpgradeable {
  using SafeCast for uint256;
  using LibRedeemQueue for LibRedeemQueue.Queue;

  IEpochFeeder private immutable _epochFeeder;
  IValidatorManager private immutable _manager;
  IValidatorStakingHub private immutable _hub;
  IConsensusValidatorEntrypoint private immutable _entrypoint;

  constructor(IEpochFeeder epochFeeder_, IValidatorManager manager_, IConsensusValidatorEntrypoint entrypoint_) {
    _epochFeeder = epochFeeder_;
    _manager = manager_;
    _entrypoint = entrypoint_;

    _disableInitializers();
  }

  function initialize(address initialOwner, uint48 unstakeCooldown_, uint48 redelegationCooldown_) external initializer {
    __UUPSUpgradeable_init();
    __Ownable_init(initialOwner);
    __Ownable2Step_init();

    StorageV1 storage $ = _getStorageV1();
    _setUnstakeCooldown($, unstakeCooldown_);
    _setRedelegationCooldown($, redelegationCooldown_);
  }

  /// @inheritdoc IValidatorStaking
  function epochFeeder() external view returns (IEpochFeeder) {
    return _epochFeeder;
  }

  /// @inheritdoc IValidatorStaking
  function manager() external view returns (IValidatorManager) {
    return _manager;
  }

  /// @inheritdoc IValidatorStaking
  function hub() external view returns (IValidatorStakingHub) {
    return _hub;
  }

  /// @inheritdoc IValidatorStaking
  function entrypoint() external view returns (IConsensusValidatorEntrypoint) {
    return _entrypoint;
  }

  /// @inheritdoc IValidatorStaking
  function totalStaked() external view returns (uint256) {
    return _getStorageV1().totalStaked;
  }

  /// @inheritdoc IValidatorStaking
  function totalUnstaking() external view returns (uint256) {
    return _getStorageV1().totalUnstaking;
  }

  /// @inheritdoc IValidatorStaking
  function unstaking(address valAddr, address staker) external view returns (uint256, uint256) {
    require(staker != address(0), StdError.InvalidParameter('staker'));
    return _unstaking(_getStorageV1(), valAddr, staker, Time.timestamp());
  }

  /// @inheritdoc IValidatorStaking
  function unstakingAt(address valAddr, address staker, uint48 timestamp) external view returns (uint256, uint256) {
    require(staker != address(0), StdError.InvalidParameter('staker'));
    require(timestamp > 0, StdError.InvalidParameter('timestamp'));
    return _unstaking(_getStorageV1(), valAddr, staker, timestamp);
  }

  /// @inheritdoc IValidatorStaking
  function unstakeCooldown() external view returns (uint48) {
    return _getStorageV1().unstakeCooldown;
  }

  /// @inheritdoc IValidatorStaking
  function redelegationCooldown() external view returns (uint48) {
    return _getStorageV1().redelegationCooldown;
  }

  /// @inheritdoc IValidatorStaking
  function lastRedelegationTime(address staker) external view returns (uint256) {
    return _getStorageV1().lastRedelegationTime[staker];
  }

  /// @inheritdoc IValidatorStaking
  function stake(address valAddr, address recipient) external payable {
    require(msg.value > 0, StdError.ZeroAmount());
    require(recipient != address(0), StdError.InvalidParameter('recipient'));
    require(_manager.isValidator(valAddr), IValidatorStaking__NotValidator());

    _hub.notifyStake(valAddr, _msgSender(), msg.value);

    StorageV1 storage $ = _getStorageV1();

    $.totalStaked += msg.value.toUint128();

    emit Staked(valAddr, _msgSender(), recipient, msg.value);
  }

  /// @inheritdoc IValidatorStaking
  function requestUnstake(address valAddr, address receiver, uint256 amount) external returns (uint256) {
    require(amount > 0, StdError.ZeroAmount());
    require(_manager.isValidator(valAddr), IValidatorStaking__NotValidator());

    _hub.notifyUnstake(valAddr, _msgSender(), amount);

    StorageV1 storage $ = _getStorageV1();

    LibRedeemQueue.Queue storage queue = $.unstakeQueue[valAddr];

    // FIXME(eddy): shorten the enqueue + reserve flow
    uint48 now_ = Time.timestamp();
    uint256 reqId = queue.enqueue(receiver, amount, now_, bytes(''));
    queue.reserve(valAddr, amount, now_, bytes(''));

    $.totalStaked -= amount.toUint128();
    $.totalUnstaking += amount.toUint128();

    emit UnstakeRequested(valAddr, _msgSender(), receiver, amount, reqId);

    return reqId;
  }

  /// @inheritdoc IValidatorStaking
  function claimUnstake(address valAddr, address receiver) external returns (uint256) {
    require(_manager.isValidator(valAddr), IValidatorStaking__NotValidator());

    StorageV1 storage $ = _getStorageV1();

    LibRedeemQueue.Queue storage queue = $.unstakeQueue[valAddr];

    queue.redeemPeriod = $.unstakeCooldown;

    uint48 now_ = Time.timestamp();
    queue.update(now_);
    uint256 claimed = queue.claim(receiver, now_);

    SafeTransferLib.safeTransferETH(receiver, claimed);

    $.totalUnstaking -= claimed.toUint128();

    emit UnstakeClaimed(valAddr, receiver, claimed);

    return claimed;
  }

  /// @inheritdoc IValidatorStaking
  function redelegate(address fromValAddr, address toValAddr, uint256 amount) external {
    require(amount > 0, StdError.ZeroAmount());
    require(fromValAddr != toValAddr, IValidatorStaking__RedelegateToSameValidator());

    StorageV1 storage $ = _getStorageV1();
    require(_manager.isValidator(fromValAddr), IValidatorStaking__NotValidator());
    require(_manager.isValidator(toValAddr), IValidatorStaking__NotValidator());

    uint48 now_ = Time.timestamp();
    uint256 lastRedelegationTime_ = $.lastRedelegationTime[_msgSender()];
    require(now_ >= lastRedelegationTime_ + $.redelegationCooldown, IValidatorStaking__CooldownNotPassed());

    _hub.notifyRedelegation(fromValAddr, toValAddr, _msgSender(), amount);

    emit Redelegated(fromValAddr, toValAddr, _msgSender(), amount);
  }

  /// @inheritdoc IValidatorStaking
  function setUnstakeCooldown(uint48 unstakeCooldown_) external onlyOwner {
    _setUnstakeCooldown(_getStorageV1(), unstakeCooldown_);
  }

  /// @inheritdoc IValidatorStaking
  function setRedelegationCooldown(uint48 redelegationCooldown_) external onlyOwner {
    _setRedelegationCooldown(_getStorageV1(), redelegationCooldown_);
  }

  // ===================================== INTERNAL FUNCTIONS ===================================== //

  function _unstaking(StorageV1 storage $, address valAddr, address staker, uint48 timestamp)
    internal
    view
    returns (uint256, uint256)
  {
    LibRedeemQueue.Queue storage queue = $.unstakeQueue[valAddr];

    uint256 offset = queue.indexes[staker].offset;
    (uint256 newOffset, bool found) = queue.searchIndexOffset(staker, type(uint256).max, timestamp);

    uint256 claimable = 0;
    uint256 nonClaimable = 0;

    if (found) {
      for (uint256 i = offset; i < newOffset; i++) {
        claimable += queue.requestAmount(i);
      }
    }

    for (uint256 i = found ? newOffset : offset; i < queue.indexes[staker].size; i++) {
      nonClaimable += queue.requestAmount(i);
    }

    return (claimable, nonClaimable);
  }

  // ========== ADMIN ACTIONS ========== //

  function _setUnstakeCooldown(StorageV1 storage $, uint48 unstakeCooldown_) internal {
    require(unstakeCooldown_ > 0, StdError.InvalidParameter('unstakeCooldown'));

    $.unstakeCooldown = unstakeCooldown_;

    emit UnstakeCooldownUpdated(unstakeCooldown_);
  }

  function _setRedelegationCooldown(StorageV1 storage $, uint48 redelegationCooldown_) internal {
    require(redelegationCooldown_ > 0, StdError.InvalidParameter('redelegationCooldown'));

    $.redelegationCooldown = redelegationCooldown_;

    emit RedelegationCooldownUpdated(redelegationCooldown_);
  }

  // ========== UUPS ========== //

  function _authorizeUpgrade(address) internal override onlyOwner { }
}
