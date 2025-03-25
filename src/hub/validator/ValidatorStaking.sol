// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { ReentrancyGuardTransient } from '@oz-v5/utils/ReentrancyGuardTransient.sol';
import { Checkpoints } from '@oz-v5/utils/structs/Checkpoints.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { SafeTransferLib } from '@solady/utils/SafeTransferLib.sol';

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
    uint48 unstakeCooldown;
    uint48 redelegationCooldown;
    uint160 totalUnstaking;
    uint256 minStakingAmount;
    uint256 minUnstakingAmount;
    // states
    Checkpoints.Trace208 totalStaked;
    mapping(address staker => uint256) lastRedelegationTime;
    mapping(address valAddr => LibRedeemQueue.Queue) unstakeQueue;
    mapping(address staker => Checkpoints.Trace208) stakerTotal;
    mapping(address staker => Checkpoints.Trace208) unstakingTotal;
    mapping(address valAddr => Checkpoints.Trace208) validatorTotal;
    mapping(address valAddr => mapping(address staker => Checkpoints.Trace208)) staked;
  }

  string private constant _NAMESPACE = 'mitosis.storage.ValidatorStaking.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}

contract ValidatorStaking is
  IValidatorStaking,
  ValidatorStakingStorageV1,
  Ownable2StepUpgradeable,
  ReentrancyGuardTransient,
  UUPSUpgradeable
{
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
  ) public virtual initializer {
    __Ownable_init(initialOwner);
    __Ownable2Step_init();
    __UUPSUpgradeable_init();

    StorageV1 storage $ = _getStorageV1();
    _setMinStakingAmount($, initialMinStakingAmount);
    _setMinUnstakingAmount($, initialMinUnstakingAmount);
    _setUnstakeCooldown($, unstakeCooldown_);
    _setRedelegationCooldown($, redelegationCooldown_);
  }

  /// @inheritdoc IValidatorStaking
  function baseAsset() external view returns (address) {
    return _baseAsset;
  }

  function manager() external view returns (IValidatorManager) {
    return _manager;
  }

  /// @inheritdoc IValidatorStaking
  function hub() external view returns (IValidatorStakingHub) {
    return _hub;
  }

  /// @inheritdoc IValidatorStaking
  function totalStaked(uint48 timestamp) public view virtual returns (uint256) {
    return _getStorageV1().totalStaked.upperLookupRecent(timestamp);
  }

  /// @inheritdoc IValidatorStaking
  function totalUnstaking() public view virtual returns (uint256) {
    return _getStorageV1().totalUnstaking;
  }

  /// @inheritdoc IValidatorStaking
  function staked(address valAddr, address staker, uint48 timestamp) public view virtual returns (uint256) {
    return _getStorageV1().staked[valAddr][staker].upperLookupRecent(timestamp);
  }

  /// @inheritdoc IValidatorStaking
  function stakerTotal(address staker, uint48 timestamp) public view virtual returns (uint256) {
    return _getStorageV1().stakerTotal[staker].upperLookupRecent(timestamp);
  }

  /// @inheritdoc IValidatorStaking
  function unstakingTotal(address staker, uint48 timestamp) public view virtual returns (uint256) {
    return _getStorageV1().unstakingTotal[staker].upperLookupRecent(timestamp);
  }

  /// @inheritdoc IValidatorStaking
  function validatorTotal(address valAddr, uint48 timestamp) public view virtual returns (uint256) {
    return _getStorageV1().validatorTotal[valAddr].upperLookupRecent(timestamp);
  }

  /// @inheritdoc IValidatorStaking
  function unstaking(address valAddr, address staker, uint48 timestamp) public view virtual returns (uint256, uint256) {
    return _unstaking(_getStorageV1(), valAddr, staker, timestamp);
  }

  /// @inheritdoc IValidatorStaking
  function minStakingAmount() public view virtual returns (uint256) {
    return _getStorageV1().minStakingAmount;
  }

  /// @inheritdoc IValidatorStaking
  function minUnstakingAmount() public view virtual returns (uint256) {
    return _getStorageV1().minUnstakingAmount;
  }

  /// @inheritdoc IValidatorStaking
  function unstakeCooldown() public view virtual returns (uint48) {
    return _getStorageV1().unstakeCooldown;
  }

  /// @inheritdoc IValidatorStaking
  function redelegationCooldown() public view virtual returns (uint48) {
    return _getStorageV1().redelegationCooldown;
  }

  /// @inheritdoc IValidatorStaking
  function lastRedelegationTime(address staker) public view virtual returns (uint256) {
    return _getStorageV1().lastRedelegationTime[staker];
  }

  /// @inheritdoc IValidatorStaking
  function stake(address valAddr, address recipient, uint256 amount) external payable returns (uint256) {
    return _stake(_getStorageV1(), valAddr, recipient, amount);
  }

  /// @inheritdoc IValidatorStaking
  function requestUnstake(address valAddr, address receiver, uint256 amount) external returns (uint256) {
    return _requestUnstake(_getStorageV1(), valAddr, receiver, amount);
  }

  /// @inheritdoc IValidatorStaking
  function claimUnstake(address valAddr, address receiver) external nonReentrant returns (uint256) {
    return _claimUnstake(_getStorageV1(), valAddr, receiver);
  }

  /// @inheritdoc IValidatorStaking
  function redelegate(address fromValAddr, address toValAddr, uint256 amount) external returns (uint256) {
    return _redelegate(_getStorageV1(), _msgSender(), fromValAddr, toValAddr, amount);
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
    uint256 currentStaked = $.staked[valAddr][staker].latest();
    uint256 minUnstaking = $.minUnstakingAmount;

    if (amount != currentStaked) {
      require(amount >= minUnstaking, IValidatorStaking__InsufficientMinimumAmount(minUnstaking));
    }
  }

  function _unstaking(StorageV1 storage $, address valAddr, address staker, uint48 timestamp)
    internal
    view
    returns (uint256, uint256)
  {
    LibRedeemQueue.Queue storage queue = $.unstakeQueue[valAddr];

    uint256 offset = queue.indexes[staker].offset;
    (uint256 newOffset, bool found) = queue.searchIndexOffset(
      staker,
      type(uint256).max,
      timestamp,
      queue.redeemPeriod != $.unstakeCooldown ? $.unstakeCooldown : queue.redeemPeriod
    );

    uint256 indexSide = queue.indexes[staker].size;
    uint256 claimable = 0;
    uint256 nonClaimable = 0;

    LibRedeemQueue.Index storage index = queue.indexes[staker];

    if (found) {
      for (uint256 i = offset; i < newOffset;) {
        claimable += queue.requestAmount(index.get(i));
        unchecked {
          ++i;
        }
      }
    }

    for (uint256 i = found ? newOffset : offset; i < indexSide;) {
      nonClaimable += queue.requestAmount(index.get(i));
      unchecked {
        ++i;
      }
    }

    return (claimable, nonClaimable);
  }

  function _stake(StorageV1 storage $, address valAddr, address recipient, uint256 amount)
    internal
    virtual
    returns (uint256)
  {
    require(amount > 0, StdError.ZeroAmount());
    require(amount >= $.minStakingAmount, IValidatorStaking__InsufficientMinimumAmount($.minStakingAmount));

    require(_baseAsset != NATIVE_TOKEN || msg.value == amount, StdError.InvalidParameter('amount'));
    require(recipient != address(0), StdError.InvalidParameter('recipient'));
    require(_manager.isValidator(valAddr), IValidatorStaking__NotValidator(valAddr));

    LibRedeemQueue.Queue storage queue = $.unstakeQueue[valAddr];
    _updateRedeemPeriod(queue, $.unstakeCooldown);

    // If the base asset is not native, we need to transfer from the sender to the contract
    if (_baseAsset != NATIVE_TOKEN) _baseAsset.safeTransferFrom(_msgSender(), address(this), amount);

    _storeStake($, valAddr, _msgSender(), amount);
    _hub.notifyStake(valAddr, _msgSender(), amount);

    emit Staked(valAddr, _msgSender(), recipient, amount);

    return amount;
  }

  function _requestUnstake(StorageV1 storage $, address valAddr, address receiver, uint256 amount)
    internal
    virtual
    returns (uint256)
  {
    require(amount > 0, StdError.ZeroAmount());
    require(_manager.isValidator(valAddr), IValidatorStaking__NotValidator(valAddr));

    address staker = _msgSender();
    _assertUnstakeAmountCondition($, valAddr, staker, amount);

    LibRedeemQueue.Queue storage queue = $.unstakeQueue[valAddr];
    _updateRedeemPeriod(queue, $.unstakeCooldown);

    // FIXME(eddy): shorten the enqueue + reserve flow
    uint48 now_ = Time.timestamp();
    uint256 reqId = queue.enqueue(receiver, amount, now_, bytes(''));
    queue.reserve(valAddr, amount, now_, bytes(''));

    _storeUnstake($, valAddr, staker, amount);

    _hub.notifyUnstake(valAddr, staker, amount);
    $.totalUnstaking += amount.toUint128();
    $.unstakingTotal[staker].push(now_, ($.unstakingTotal[staker].latest() + amount).toUint208());

    emit UnstakeRequested(valAddr, staker, receiver, amount, reqId);

    return reqId;
  }

  function _claimUnstake(StorageV1 storage $, address valAddr, address receiver) internal virtual returns (uint256) {
    require(_manager.isValidator(valAddr), IValidatorStaking__NotValidator(valAddr));

    LibRedeemQueue.Queue storage queue = $.unstakeQueue[valAddr];
    _updateRedeemPeriod(queue, $.unstakeCooldown);

    uint48 now_ = Time.timestamp();
    queue.update(now_);
    uint256 claimed = queue.claim(receiver, now_);

    if (_baseAsset == NATIVE_TOKEN) receiver.safeTransferETH(claimed);
    else _baseAsset.safeTransfer(receiver, claimed);

    $.totalUnstaking -= claimed.toUint128();
    $.unstakingTotal[receiver].push(now_, ($.unstakingTotal[receiver].latest() - claimed).toUint208());

    emit UnstakeClaimed(valAddr, receiver, claimed);

    return claimed;
  }

  function _redelegate(StorageV1 storage $, address delegator, address fromValAddr, address toValAddr, uint256 amount)
    internal
    virtual
    returns (uint256)
  {
    require(amount > 0, StdError.ZeroAmount());
    require(fromValAddr != toValAddr, IValidatorStaking__RedelegateToSameValidator(fromValAddr));

    _assertUnstakeAmountCondition($, fromValAddr, delegator, amount);

    require(_manager.isValidator(fromValAddr), IValidatorStaking__NotValidator(fromValAddr));
    require(_manager.isValidator(toValAddr), IValidatorStaking__NotValidator(toValAddr));

    {
      uint256 unstakeCooldown_ = $.unstakeCooldown;
      _updateRedeemPeriod($.unstakeQueue[fromValAddr], unstakeCooldown_);
      _updateRedeemPeriod($.unstakeQueue[toValAddr], unstakeCooldown_);
    }

    uint48 now_ = Time.timestamp();
    uint256 lastRedelegationTime_ = $.lastRedelegationTime[delegator];

    if (lastRedelegationTime_ > 0) {
      uint48 cooldown = $.redelegationCooldown;
      uint48 lasttime = lastRedelegationTime_.toUint48();
      require(
        now_ >= lasttime + cooldown, //
        IValidatorStaking__CooldownNotPassed(lasttime, now_, (lasttime + cooldown) - now_)
      );
    }
    $.lastRedelegationTime[delegator] = now_;

    _storeUnstake($, fromValAddr, delegator, amount);
    _storeStake($, toValAddr, delegator, amount);

    _hub.notifyRedelegation(fromValAddr, toValAddr, delegator, amount);

    emit Redelegated(fromValAddr, toValAddr, delegator, amount);

    return amount;
  }

  function _updateRedeemPeriod(LibRedeemQueue.Queue storage queue, uint256 cooldown) internal virtual {
    if (queue.redeemPeriod != cooldown) queue.redeemPeriod = cooldown;
  }

  function _storeStake(StorageV1 storage $, address valAddr, address staker, uint256 amount) internal virtual {
    uint48 now_ = Time.timestamp();
    uint208 newTotalStaked;
    uint208 newStakerTotal;
    uint208 newValidatorTotal;
    uint208 newStaked;

    unchecked {
      newTotalStaked = ($.totalStaked.latest() + amount).toUint208();
      newStakerTotal = ($.stakerTotal[staker].latest() + amount).toUint208();
      newValidatorTotal = ($.validatorTotal[valAddr].latest() + amount).toUint208();
      newStaked = ($.staked[valAddr][staker].latest() + amount).toUint208();
    }

    $.totalStaked.push(now_, newTotalStaked);
    $.stakerTotal[staker].push(now_, newStakerTotal);
    $.validatorTotal[valAddr].push(now_, newValidatorTotal);
    $.staked[valAddr][staker].push(now_, newStaked);
  }

  function _storeUnstake(StorageV1 storage $, address valAddr, address staker, uint256 amount) internal virtual {
    uint48 now_ = Time.timestamp();

    $.totalStaked.push(now_, ($.totalStaked.latest() - amount).toUint208());
    $.stakerTotal[staker].push(now_, ($.stakerTotal[staker].latest() - amount).toUint208());
    $.validatorTotal[valAddr].push(now_, ($.validatorTotal[valAddr].latest() - amount).toUint208());
    $.staked[valAddr][staker].push(now_, ($.staked[valAddr][staker].latest() - amount).toUint208());
  }

  // ========== ADMIN ACTIONS ========== //

  function _setMinStakingAmount(StorageV1 storage $, uint256 minAmount) internal virtual {
    uint256 previous = $.minStakingAmount;
    $.minStakingAmount = minAmount;
    emit MinimumStakingAmountSet(previous, minAmount);
  }

  function _setMinUnstakingAmount(StorageV1 storage $, uint256 minAmount) internal virtual {
    uint256 previous = $.minUnstakingAmount;
    $.minUnstakingAmount = minAmount;
    emit MinimumUnstakingAmountSet(previous, minAmount);
  }

  function _setUnstakeCooldown(StorageV1 storage $, uint48 unstakeCooldown_) internal virtual {
    require(unstakeCooldown_ > 0, StdError.InvalidParameter('unstakeCooldown'));

    $.unstakeCooldown = unstakeCooldown_;

    emit UnstakeCooldownUpdated(unstakeCooldown_);
  }

  function _setRedelegationCooldown(StorageV1 storage $, uint48 redelegationCooldown_) internal virtual {
    require(redelegationCooldown_ > 0, StdError.InvalidParameter('redelegationCooldown'));

    $.redelegationCooldown = redelegationCooldown_;

    emit RedelegationCooldownUpdated(redelegationCooldown_);
  }

  //============ UUPS ============ //

  function _authorizeUpgrade(address) internal override onlyOwner { }
}
