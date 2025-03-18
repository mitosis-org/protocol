// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Checkpoints } from '@oz-v5/utils/structs/Checkpoints.sol';
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
    // configs
    uint256 minStakingAmount;
    uint256 minUnstakingAmount;
    uint48 unstakeCooldown;
    uint48 redelegationCooldown;
    // states
    uint160 totalUnstaking;
    Checkpoints.Trace208 totalStaked;
    mapping(address staker => uint256) lastRedelegationTime;
    mapping(address valAddr => LibRedeemQueue.Queue) unstakeQueue;
    mapping(address staker => Checkpoints.Trace208) stakerTotal;
    mapping(address valAddr => Checkpoints.Trace208) validatorTotal;
    mapping(address valAddr => mapping(address staker => Checkpoints.Trace208)) staked;
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
  using LibRedeemQueue for LibRedeemQueue.Index;
  using Checkpoints for Checkpoints.Trace208;

  address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  address private immutable _baseAsset;
  IValidatorManager private immutable _manager;
  IValidatorStakingHub private immutable _hub;

  constructor(address baseAsset_, IValidatorManager manager_, IValidatorStakingHub hub_) {
    _baseAsset = baseAsset_ == address(0) ? NATIVE_TOKEN : baseAsset_;
    _manager = manager_;
    _hub = hub_;

    _disableInitializers();
  }

  function initialize(
    address initialOwner,
    uint256 initialMinStakingAmount,
    uint256 initialMinUnstakingAmount,
    uint48 unstakeCooldown_,
    uint48 redelegationCooldown_
  ) external initializer {
    __UUPSUpgradeable_init();
    __Ownable_init(initialOwner);
    __Ownable2Step_init();

    StorageV1 storage $ = _getStorageV1();
    _setMinStakingAmount($, initialMinStakingAmount);
    _setMinUnstakingAmount($, initialMinUnstakingAmount);
    _setUnstakeCooldown($, unstakeCooldown_);
    _setRedelegationCooldown($, redelegationCooldown_);
  }

  /// @inheritdoc IValidatorStaking
  function baseAsset() public view returns (address) {
    return _baseAsset;
  }

  function manager() external view returns (IValidatorManager) {
    return _manager;
  }

  /// @inheritdoc IValidatorStaking
  function hub() public view returns (IValidatorStakingHub) {
    return _hub;
  }

  /// @inheritdoc IValidatorStaking
  function totalStaked(uint48 timestamp) external view returns (uint256) {
    return _getStorageV1().totalStaked.upperLookup(timestamp);
  }

  /// @inheritdoc IValidatorStaking
  function totalUnstaking() external view returns (uint256) {
    return _getStorageV1().totalUnstaking;
  }

  /// @inheritdoc IValidatorStaking
  function staked(address valAddr, address staker, uint48 timestamp) external view returns (uint256) {
    return _getStorageV1().staked[valAddr][staker].upperLookup(timestamp);
  }

  /// @inheritdoc IValidatorStaking
  function stakerTotal(address staker, uint48 timestamp) external view returns (uint256) {
    return _getStorageV1().stakerTotal[staker].upperLookup(timestamp);
  }

  /// @inheritdoc IValidatorStaking
  function validatorTotal(address valAddr, uint48 timestamp) external view returns (uint256) {
    return _getStorageV1().validatorTotal[valAddr].upperLookup(timestamp);
  }

  /// @inheritdoc IValidatorStaking
  function unstaking(address valAddr, address staker, uint48 timestamp) external view returns (uint256, uint256) {
    return _unstaking(_getStorageV1(), valAddr, staker, timestamp);
  }

  /// @inheritdoc IValidatorStaking
  function minStakingAmount() external view returns (uint256) {
    return _getStorageV1().minStakingAmount;
  }

  /// @inheritdoc IValidatorStaking
  function minUnstakingAmount() external view returns (uint256) {
    return _getStorageV1().minUnstakingAmount;
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
  function stake(address valAddr, address recipient, uint256 amount) public payable virtual {
    require(amount > 0, StdError.ZeroAmount());

    StorageV1 storage $ = _getStorageV1();
    require(amount >= $.minStakingAmount, IValidatorStaking__InsufficientMinimumAmount());

    require(_baseAsset != NATIVE_TOKEN || msg.value == amount, StdError.InvalidParameter('amount'));
    require(recipient != address(0), StdError.InvalidParameter('recipient'));
    require(_manager.isValidator(valAddr), IValidatorStaking__NotValidator());

    // If the base asset is not native, we need to transfer from the sender to the contract
    if (_baseAsset != NATIVE_TOKEN) _baseAsset.safeTransferFrom(_msgSender(), address(this), amount);

    _stake($, valAddr, _msgSender(), amount);
    _hub.notifyStake(valAddr, _msgSender(), amount);

    emit Staked(valAddr, _msgSender(), recipient, amount);
  }

  /// @inheritdoc IValidatorStaking
  function requestUnstake(address valAddr, address receiver, uint256 amount) public virtual returns (uint256) {
    require(amount > 0, StdError.ZeroAmount());
    require(_manager.isValidator(valAddr), IValidatorStaking__NotValidator());

    StorageV1 storage $ = _getStorageV1();

    address staker = _msgSender();
    _assertUnstakeAmountCondition($, valAddr, staker, amount);

    return _requestUnstake($, staker, valAddr, receiver, amount);
  }

  /// @inheritdoc IValidatorStaking
  function claimUnstake(address valAddr, address receiver) public virtual returns (uint256) {
    require(_manager.isValidator(valAddr), IValidatorStaking__NotValidator());

    StorageV1 storage $ = _getStorageV1();

    LibRedeemQueue.Queue storage queue = $.unstakeQueue[valAddr];
    if (queue.redeemPeriod != $.unstakeCooldown) queue.redeemPeriod = $.unstakeCooldown;

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
  function redelegate(address fromValAddr, address toValAddr, uint256 amount) public virtual {
    require(amount > 0, StdError.ZeroAmount());
    require(fromValAddr != toValAddr, IValidatorStaking__RedelegateToSameValidator());

    StorageV1 storage $ = _getStorageV1();

    address delegator = _msgSender();
    _assertUnstakeAmountCondition($, fromValAddr, delegator, amount);

    _redelegate($, delegator, fromValAddr, toValAddr, amount);
  }

  /// @inheritdoc IValidatorStaking
  function setMinStakingAmount(uint256 minAmount) external onlyOwner {
    _setMinStakingAmount(_getStorageV1(), minAmount);
  }

  /// @inheritdoc IValidatorStaking
  function setMinUnstakingAmount(uint256 minAmount) external onlyOwner {
    _setMinUnstakingAmount(_getStorageV1(), minAmount);
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

  function _assertUnstakeAmountCondition(StorageV1 storage $, address valAddr, address staker, uint256 amount)
    internal
    view
  {
    // We allow unstaking for the entire amount even if the minAmount is not met.
    if (amount != $.staked[valAddr][staker].latest()) {
      require(amount >= $.minUnstakingAmount, IValidatorStaking__InsufficientMinimumAmount());
    }
  }

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

    LibRedeemQueue.Index storage index = queue.indexes[staker];

    if (found) {
      for (uint256 i = offset; i < newOffset; i++) {
        claimable += queue.requestAmount(index.get(i));
      }
    }

    for (uint256 i = found ? newOffset : offset; i < index.size; i++) {
      nonClaimable += queue.requestAmount(index.get(i));
    }

    return (claimable, nonClaimable);
  }

  function _requestUnstake(StorageV1 storage $, address staker, address valAddr, address receiver, uint256 amount)
    internal
    returns (uint256)
  {
    require(amount > 0, StdError.ZeroAmount());
    require(_manager.isValidator(valAddr), IValidatorStaking__NotValidator());

    LibRedeemQueue.Queue storage queue = $.unstakeQueue[valAddr];

    // FIXME(eddy): shorten the enqueue + reserve flow
    uint48 now_ = Time.timestamp();
    uint256 reqId = queue.enqueue(receiver, amount, now_, bytes(''));
    queue.reserve(valAddr, amount, now_, bytes(''));

    _unstake($, valAddr, staker, amount);

    _hub.notifyUnstake(valAddr, staker, amount);
    $.totalUnstaking += amount.toUint128();

    emit UnstakeRequested(valAddr, staker, receiver, amount, reqId);

    return reqId;
  }

  function _redelegate(StorageV1 storage $, address delegator, address fromValAddr, address toValAddr, uint256 amount)
    internal
  {
    require(amount > 0, StdError.ZeroAmount());
    require(fromValAddr != toValAddr, IValidatorStaking__RedelegateToSameValidator());

    require(_manager.isValidator(fromValAddr), IValidatorStaking__NotValidator());
    require(_manager.isValidator(toValAddr), IValidatorStaking__NotValidator());

    uint48 now_ = Time.timestamp();
    uint256 lastRedelegationTime_ = $.lastRedelegationTime[delegator];
    require(now_ >= lastRedelegationTime_ + $.redelegationCooldown, IValidatorStaking__CooldownNotPassed());

    _unstake($, fromValAddr, delegator, amount);
    _stake($, toValAddr, delegator, amount);

    _hub.notifyRedelegation(fromValAddr, toValAddr, delegator, amount);

    emit Redelegated(fromValAddr, toValAddr, delegator, amount);
  }

  function _stake(StorageV1 storage $, address valAddr, address staker, uint256 amount) internal {
    uint48 now_ = Time.timestamp();

    $.totalStaked.push(now_, ($.totalStaked.latest() + amount).toUint208());
    $.stakerTotal[staker].push(now_, ($.stakerTotal[staker].latest() + amount).toUint208());
    $.validatorTotal[valAddr].push(now_, ($.validatorTotal[valAddr].latest() + amount).toUint208());
    $.staked[valAddr][staker].push(now_, ($.staked[valAddr][staker].latest() + amount).toUint208());
  }

  function _unstake(StorageV1 storage $, address valAddr, address staker, uint256 amount) internal {
    uint48 now_ = Time.timestamp();

    $.totalStaked.push(now_, ($.totalStaked.latest() - amount).toUint208());
    $.stakerTotal[staker].push(now_, ($.stakerTotal[staker].latest() - amount).toUint208());
    $.validatorTotal[valAddr].push(now_, ($.validatorTotal[valAddr].latest() - amount).toUint208());
    $.staked[valAddr][staker].push(now_, ($.staked[valAddr][staker].latest() - amount).toUint208());
  }

  // ========== ADMIN ACTIONS ========== //

  function _setMinStakingAmount(StorageV1 storage $, uint256 minAmount) internal {
    uint256 previous = $.minStakingAmount;
    $.minStakingAmount = minAmount;
    emit MinimumStakingAmountSet(previous, minAmount);
  }

  function _setMinUnstakingAmount(StorageV1 storage $, uint256 minAmount) internal {
    uint256 previous = $.minUnstakingAmount;
    $.minUnstakingAmount = minAmount;
    emit MinimumUnstakingAmountSet(previous, minAmount);
  }

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
