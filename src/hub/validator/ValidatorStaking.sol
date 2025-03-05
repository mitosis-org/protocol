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
    address baseAsset;
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
  using SafeTransferLib for address;
  using LibRedeemQueue for LibRedeemQueue.Queue;

  address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  address private immutable _baseAsset;
  IEpochFeeder private immutable _epochFeeder;
  IValidatorManager private immutable _manager;
  IValidatorStakingHub private immutable _hub;
  IConsensusValidatorEntrypoint private immutable _entrypoint;

  constructor(
    address baseAsset_,
    IEpochFeeder epochFeeder_,
    IValidatorManager manager_,
    IConsensusValidatorEntrypoint entrypoint_
  ) {
    _baseAsset = baseAsset_;
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
  function totalDelegationForStaker(address staker) external view returns (uint256) {
    return _totalDelegationForStaker(_getStorageV1(), staker, Time.timestamp());
  }

  /// @inheritdoc IValidatorStaking
  function totalDelegationForStakerAt(address staker, uint48 timestamp) external view returns (uint256) {
    require(timestamp > 0, StdError.InvalidParameter('timestamp'));
    return _totalDelegationForStaker(_getStorageV1(), staker, timestamp);
  }

  /// @inheritdoc IValidatorStaking
  function totalDelegationTWABForStaker(address staker) external view returns (uint256) {
    return _totalDelegationTWABForStaker(_getStorageV1(), staker, Time.timestamp());
  }

  /// @inheritdoc IValidatorStaking
  function totalDelegationTWABForStakerAt(address staker, uint48 timestamp) external view returns (uint256) {
    require(timestamp > 0, StdError.InvalidParameter('timestamp'));
    return _totalDelegationTWABForStaker(_getStorageV1(), staker, timestamp);
  }

  /// @inheritdoc IValidatorStaking
  function lastRedelegationTime(address staker) external view returns (uint256) {
    return _getStorageV1().lastRedelegationTime[staker];
  }

  /// @inheritdoc IValidatorStaking
  function stake(address valAddr, address recipient, uint256 amount) external payable {
    require(amount > 0, StdError.ZeroAmount());

    require(_baseAsset == NATIVE_TOKEN && msg.value == amount, StdError.InvalidParameter('amount'));
    require(recipient != address(0), StdError.InvalidParameter('recipient'));
    require(_manager.isValidator(valAddr), IValidatorStaking__NotValidator());

    // If the base asset is not native, we need to transfer from the sender to the contract
    if (_baseAsset != NATIVE_TOKEN) _baseAsset.safeTransferFrom(_msgSender(), address(this), amount);

    StorageV1 storage $ = _getStorageV1();

    _stake($, valAddr, recipient, amount, Time.timestamp());

    $.totalStaked += amount.toUint128();

    // FIXME(eddy): make this as a hook - for multiple staking contracts
    _entrypoint.updateExtraVotingPower(
      _manager.validatorInfo(valAddr).valKey, // can be optimized
      _last($.totalDelegations[valAddr]).amount
    );

    emit Staked(valAddr, _msgSender(), recipient, amount);
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

    if (_baseAsset == NATIVE_TOKEN) receiver.safeTransferETH(claimed);
    else _baseAsset.safeTransfer(receiver, claimed);

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

    _entrypoint.updateExtraVotingPower(
      _manager.validatorInfo(fromValAddr).valKey, // can be optimized
      _last($.totalDelegations[fromValAddr]).amount
    );

    _entrypoint.updateExtraVotingPower(
      _manager.validatorInfo(toValAddr).valKey, // can be optimized
      _last($.totalDelegations[toValAddr]).amount
    );

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

  function _totalDelegation(StorageV1 storage $, address valAddr, uint48 timestamp) internal view returns (uint256) {
    TWABCheckpoint[] storage history = $.totalDelegations[valAddr];
    if (history.length == 0) return 0;

    return _searchCheckpoint(history, timestamp).amount;
  }

  function _totalDelegationTWAB(StorageV1 storage $, address valAddr, uint48 timestamp) internal view returns (uint256) {
    TWABCheckpoint[] storage history = $.totalDelegations[valAddr];
    if (history.length == 0) return 0;

    TWABCheckpoint memory last = _searchCheckpoint(history, timestamp);
    return last.twab + (last.amount * (timestamp - last.lastUpdate));
  }

  function _totalDelegationForStaker(StorageV1 storage $, address staker, uint48 timestamp)
    internal
    view
    returns (uint256)
  {
    TWABCheckpoint[] storage history = $.totalDelegationsForStaker[staker];
    if (history.length == 0) return 0;

    return _searchCheckpoint(history, timestamp).amount;
  }

  function _totalDelegationTWABForStaker(StorageV1 storage $, address staker, uint48 timestamp)
    internal
    view
    returns (uint256)
  {
    TWABCheckpoint[] storage history = $.totalDelegationsForStaker[staker];
    if (history.length == 0) return 0;

    TWABCheckpoint memory last = _searchCheckpoint(history, timestamp);
    return last.twab + (last.amount * (timestamp - last.lastUpdate));
  }

  function _stake(StorageV1 storage $, address valAddr, address recipient, uint256 amount, uint48 now_) internal {
    _pushTWABCheckpoint($.totalDelegationsForStaker[recipient], amount, now_, _addAmount);
    _pushTWABCheckpoint($.totalDelegations[valAddr], amount, now_, _addAmount);
    _pushTWABCheckpoint($.delegationLogs[valAddr][recipient], amount, now_, _addAmount);
  }

  function _unstake(StorageV1 storage $, address valAddr, address recipient, uint256 amount) internal {
    uint48 now_ = Time.timestamp();

    _pushTWABCheckpoint($.totalDelegationsForStaker[recipient], amount, now_, _subAmount);
    _pushTWABCheckpoint($.totalDelegations[valAddr], amount, now_, _subAmount);
    _pushTWABCheckpoint($.delegationLogs[valAddr][recipient], amount, now_, _subAmount);
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
