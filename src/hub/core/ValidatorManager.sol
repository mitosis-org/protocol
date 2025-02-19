// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { Math } from '@oz-v5/utils/math/Math.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { EnumerableMap } from '@oz-v5/utils/structs/EnumerableMap.sol';
import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';

import { SafeTransferLib } from '@solady/utils/SafeTransferLib.sol';

import { IConsensusValidatorEntrypoint } from '../../interfaces/hub/consensus-layer/IConsensusValidatorEntrypoint.sol';
import { IEpochFeeder } from '../../interfaces/hub/core/IEpochFeeder.sol';
import { IValidatorManager } from '../../interfaces/hub/core/IValidatorManager.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { LibRedeemQueue } from '../../lib/LibRedeemQueue.sol';
import { LibSecp256k1 } from '../../lib/LibSecp256k1.sol';
import { StdError } from '../../lib/StdError.sol';

contract ValidatorManagerStorageV1 {
  using ERC7201Utils for string;

  struct TWABCheckpoint {
    uint256 amount;
    uint208 twab;
    uint48 lastUpdate;
  }

  struct EpochCheckpoint {
    uint96 epoch;
    uint256 amount;
  }

  struct GlobalValidatorConfig {
    uint256 initialValidatorDeposit; // used on creation of the validator
    uint256 unstakeCooldown; // in seconds
    uint256 redelegationCooldown; // in seconds
    uint256 collateralWithdrawalDelay; // in seconds
    EpochCheckpoint[] minimumCommissionRates;
    uint96 commissionRateUpdateDelay; // in epoch
  }

  struct ValidatorRewardConfig {
    EpochCheckpoint[] commissionRates; // bp ex) 10000 = 100%
    uint256 pendingCommissionRate; // bp ex) 10000 = 100%
    uint256 pendingCommissionRateUpdateEpoch; // current epoch + 2
  }

  struct Validator {
    address validator;
    address operator;
    address rewardRecipient;
    bytes pubKey;
    ValidatorRewardConfig rewardConfig;
    // TBD: Metadata format
    // 1. name
    // 2. moniker
    // 3. description
    // 4. website
    // 5. image url
    // 6. ...
    // This will be applied immediately
    bytes metadata;
    // storages
    LibRedeemQueue.Queue unstakeQueue;
    TWABCheckpoint[] totalDelegations;
    mapping(address staker => TWABCheckpoint[]) delegationLog;
  }

  struct StorageV1 {
    IEpochFeeder epochFeeder;
    IConsensusValidatorEntrypoint entrypoint;
    GlobalValidatorConfig globalValidatorConfig;
    uint256 totalStaked;
    uint256 totalUnstaking;
    mapping(address staker => uint256) lastRedelegationTime;
    // validator
    uint256 validatorCount;
    mapping(uint256 index => Validator) validators;
    mapping(address valAddr => uint256 index) indexByValAddr;
  }

  string private constant _NAMESPACE = 'mitosis.storage.ValidatorManagerStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}

contract ValidatorManager is IValidatorManager, ValidatorManagerStorageV1, Ownable2StepUpgradeable, UUPSUpgradeable {
  using SafeCast for uint256;
  using EnumerableMap for EnumerableMap.AddressToUintMap;
  using EnumerableSet for EnumerableSet.AddressSet;
  using LibRedeemQueue for LibRedeemQueue.Queue;

  uint256 public constant MAX_COMMISSION_RATE = 10000; // 100% in bp

  // NOTE: This is a temporary limit. It will be revised in the next version.
  uint256 public constant MAX_STAKED_VALIDATOR_COUNT = 10;

  // NOTE: This is a temporary limit. It will be revised in the next version.
  uint256 public constant MAX_REDELEGATION_COUNT = 100;

  constructor() {
    _disableInitializers();
  }

  function initialize(
    address initialOwner,
    IEpochFeeder epochFeeder_,
    IConsensusValidatorEntrypoint entrypoint_,
    SetGlobalValidatorConfigRequest memory initialGlobalValidatorConfig
  ) external initializer {
    __UUPSUpgradeable_init();
    __Ownable_init(initialOwner);
    __Ownable2Step_init();

    StorageV1 storage $ = _getStorageV1();
    _setEpochFeeder($, epochFeeder_);
    _setEntrypoint($, entrypoint_);
    _setGlobalValidatorConfig($, initialGlobalValidatorConfig);

    $.validatorCount = 1;
  }

  /// @inheritdoc IValidatorManager
  function entrypoint() external view returns (IConsensusValidatorEntrypoint) {
    return _getStorageV1().entrypoint;
  }

  /// @inheritdoc IValidatorManager
  function epochFeeder() external view returns (IEpochFeeder) {
    return _getStorageV1().epochFeeder;
  }

  /// @inheritdoc IValidatorManager
  function globalValidatorConfig() external view returns (GlobalValidatorConfigResponse memory) {
    StorageV1 storage $ = _getStorageV1();
    GlobalValidatorConfig memory config = $.globalValidatorConfig;

    return GlobalValidatorConfigResponse({
      initialValidatorDeposit: config.initialValidatorDeposit,
      unstakeCooldown: config.unstakeCooldown,
      redelegationCooldown: config.redelegationCooldown,
      collateralWithdrawalDelay: config.collateralWithdrawalDelay,
      minimumCommissionRate: config.minimumCommissionRates[config.minimumCommissionRates.length - 1].amount,
      commissionRateUpdateDelay: config.commissionRateUpdateDelay
    });
  }

  /// @inheritdoc IValidatorManager
  function validatorCount() external view returns (uint256) {
    return _getStorageV1().validatorCount - 1;
  }

  /// @inheritdoc IValidatorManager
  function validatorAt(uint256 index) external view returns (address) {
    StorageV1 storage $ = _getStorageV1();
    return $.validators[index + 1].validator;
  }

  /// @inheritdoc IValidatorManager
  function isValidator(address valAddr) external view returns (bool) {
    StorageV1 storage $ = _getStorageV1();
    return $.indexByValAddr[valAddr] != 0;
  }

  /// @inheritdoc IValidatorManager
  function validatorInfo(address valAddr) public view returns (ValidatorInfoResponse memory) {
    return validatorInfoAt(_getStorageV1().epochFeeder.epoch(), valAddr);
  }

  /// @inheritdoc IValidatorManager
  function validatorInfoAt(uint96 epoch, address valAddr) public view returns (ValidatorInfoResponse memory) {
    StorageV1 storage $ = _getStorageV1();
    Validator storage info = _validator($, valAddr);

    uint256 commissionRate = _searchCheckpoint(info.rewardConfig.commissionRates, epoch).amount;

    ValidatorInfoResponse memory response = ValidatorInfoResponse({
      validator: info.validator,
      operator: info.operator,
      rewardRecipient: info.rewardRecipient,
      commissionRate: commissionRate,
      metadata: info.metadata
    });

    // apply pending rate
    if (info.rewardConfig.pendingCommissionRateUpdateEpoch >= epoch) {
      response.commissionRate = info.rewardConfig.pendingCommissionRate;
    }

    // hard limit
    response.commissionRate =
      Math.max(response.commissionRate, _searchCheckpoint($.globalValidatorConfig.minimumCommissionRates, epoch).amount);

    return response;
  }

  /// @inheritdoc IValidatorManager
  function totalStaked() external view returns (uint256) {
    return _getStorageV1().totalStaked;
  }

  /// @inheritdoc IValidatorManager
  function totalUnstaking() external view returns (uint256) {
    return _getStorageV1().totalUnstaking;
  }

  /// @inheritdoc IValidatorManager
  function staked(address valAddr, address staker) external view returns (uint256) {
    require(staker != address(0), StdError.InvalidParameter('staker'));
    return _staked(valAddr, staker, _getStorageV1().epochFeeder.clock());
  }

  /// @inheritdoc IValidatorManager
  function stakedAt(address valAddr, address staker, uint48 timestamp) external view returns (uint256) {
    require(staker != address(0), StdError.InvalidParameter('staker'));
    require(timestamp > 0, StdError.InvalidParameter('timestamp'));
    return _staked(valAddr, staker, timestamp);
  }

  /// @inheritdoc IValidatorManager
  function stakedTWAB(address valAddr, address staker) external view returns (uint256) {
    require(staker != address(0), StdError.InvalidParameter('staker'));
    return _stakedTWAB(valAddr, staker, _getStorageV1().epochFeeder.clock());
  }

  /// @inheritdoc IValidatorManager
  function stakedTWABAt(address valAddr, address staker, uint48 timestamp) external view returns (uint256) {
    require(staker != address(0), StdError.InvalidParameter('staker'));
    require(timestamp > 0, StdError.InvalidParameter('timestamp'));
    return _stakedTWAB(valAddr, staker, timestamp);
  }

  /// @inheritdoc IValidatorManager
  function unstaking(address valAddr, address staker) external view returns (uint256, uint256) {
    require(staker != address(0), StdError.InvalidParameter('staker'));
    return _unstaking(valAddr, staker, _getStorageV1().epochFeeder.clock());
  }

  /// @inheritdoc IValidatorManager
  function unstakingAt(address valAddr, address staker, uint48 timestamp) external view returns (uint256, uint256) {
    require(staker != address(0), StdError.InvalidParameter('staker'));
    require(timestamp > 0, StdError.InvalidParameter('timestamp'));
    return _unstaking(valAddr, staker, timestamp);
  }

  /// @inheritdoc IValidatorManager
  function totalDelegation(address valAddr) external view returns (uint256) {
    return _totalDelegation(valAddr, _getStorageV1().epochFeeder.clock());
  }

  /// @inheritdoc IValidatorManager
  function totalDelegationAt(address valAddr, uint48 timestamp) external view returns (uint256) {
    require(timestamp > 0, StdError.InvalidParameter('timestamp'));
    return _totalDelegation(valAddr, timestamp);
  }

  /// @inheritdoc IValidatorManager
  function totalDelegationTWAB(address valAddr) external view returns (uint256) {
    return _totalDelegationTWAB(valAddr, _getStorageV1().epochFeeder.clock());
  }

  /// @inheritdoc IValidatorManager
  function totalDelegationTWABAt(address valAddr, uint48 timestamp) external view returns (uint256) {
    require(timestamp > 0, StdError.InvalidParameter('timestamp'));
    return _totalDelegationTWAB(valAddr, timestamp);
  }

  /// @inheritdoc IValidatorManager
  function lastRedelegationTime(address staker) external view returns (uint256) {
    return _getStorageV1().lastRedelegationTime[staker];
  }

  /// @inheritdoc IValidatorManager
  function stake(address valAddr, address recipient) external payable {
    require(msg.value > 0, StdError.ZeroAmount());
    require(recipient != address(0), StdError.InvalidParameter('recipient'));

    StorageV1 storage $ = _getStorageV1();
    _assertValidatorExists($, valAddr);

    _stake($, valAddr, recipient, msg.value, $.epochFeeder.clock());

    $.totalStaked += msg.value;

    emit Staked(valAddr, _msgSender(), recipient, msg.value);
  }

  /// @inheritdoc IValidatorManager
  function requestUnstake(address valAddr, address receiver, uint256 amount) external returns (uint256) {
    require(amount > 0, StdError.ZeroAmount());

    StorageV1 storage $ = _getStorageV1();
    Validator storage validator = _validator($, valAddr);

    _unstake($, valAddr, _msgSender(), amount);

    LibRedeemQueue.Queue storage queue = validator.unstakeQueue;

    // FIXME(eddy): shorten the enqueue + reserve flow
    uint48 now_ = $.epochFeeder.clock();
    uint256 reqId = queue.enqueue(receiver, amount, now_, bytes(''));
    queue.reserve(valAddr, amount, now_, bytes(''));

    $.totalStaked -= amount;
    $.totalUnstaking += amount;

    emit UnstakeRequested(valAddr, _msgSender(), receiver, amount, reqId);

    return reqId;
  }

  /// @inheritdoc IValidatorManager
  function claimUnstake(address valAddr, address receiver) external returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    Validator storage validator = _validator($, valAddr);

    LibRedeemQueue.Queue storage queue = validator.unstakeQueue;

    uint256 globalCooldown = $.globalValidatorConfig.unstakeCooldown;
    if (globalCooldown != 0) queue.redeemPeriod = globalCooldown;

    uint48 now_ = $.epochFeeder.clock();
    queue.update(now_);
    uint256 claimed = queue.claim(receiver, now_);

    SafeTransferLib.safeTransferETH(receiver, claimed);

    $.totalUnstaking -= claimed;

    emit UnstakeClaimed(valAddr, receiver, claimed);

    return claimed;
  }

  /// @inheritdoc IValidatorManager
  function redelegate(address fromValAddr, address toValAddr, uint256 amount) external {
    require(amount > 0, StdError.ZeroAmount());
    require(fromValAddr != toValAddr, StdError.InvalidParameter('from!=to'));

    StorageV1 storage $ = _getStorageV1();
    _assertValidatorExists($, fromValAddr);
    _assertValidatorExists($, toValAddr);

    uint48 now_ = $.epochFeeder.clock();
    uint256 lastRedelegationTime_ = $.lastRedelegationTime[_msgSender()];
    require(
      lastRedelegationTime_ == 0 || now_ <= lastRedelegationTime_ + $.globalValidatorConfig.redelegationCooldown,
      StdError.Unauthorized()
    );

    _unstake($, fromValAddr, _msgSender(), amount);
    _stake($, toValAddr, _msgSender(), amount, now_);

    emit Redelegated(fromValAddr, toValAddr, _msgSender(), amount);
  }

  /// @inheritdoc IValidatorManager
  function createValidator(bytes calldata valKey, CreateValidatorRequest calldata request) external payable {
    require(valKey.length > 0, StdError.InvalidParameter('valKey'));

    address valAddr = _msgSender();

    // verify the valKey is valid and corresponds to the caller
    LibSecp256k1.verifyCmpPubkeyWithAddress(valKey, valAddr);

    StorageV1 storage $ = _getStorageV1();
    _assertValidatorNotExists($, valAddr);

    GlobalValidatorConfig memory globalConfig = $.globalValidatorConfig;

    require(globalConfig.initialValidatorDeposit <= msg.value, StdError.InvalidParameter('msg.value'));
    require(
      globalConfig.minimumCommissionRates[globalConfig.minimumCommissionRates.length - 1].amount
        <= request.commissionRate && request.commissionRate <= MAX_COMMISSION_RATE,
      StdError.InvalidParameter('commissionRate')
    );

    // start from 1
    uint256 valIndex = $.validatorCount++;

    uint96 epoch = $.epochFeeder.epoch();

    Validator storage validator = $.validators[valIndex];
    validator.validator = valAddr;
    validator.operator = valAddr;
    validator.rewardRecipient = valAddr;
    validator.pubKey = valKey;
    validator.rewardConfig.commissionRates.push(EpochCheckpoint({ epoch: epoch, amount: request.commissionRate }));
    validator.metadata = request.metadata;
    validator.unstakeQueue.redeemPeriod = $.globalValidatorConfig.unstakeCooldown;

    $.indexByValAddr[valAddr] = valIndex;
    $.entrypoint.registerValidator{ value: msg.value }(valKey, valAddr);

    emit ValidatorCreated(valAddr, valKey);
  }

  /// @inheritdoc IValidatorManager
  function depositCollateral(address valAddr) external payable {
    require(msg.value > 0, StdError.ZeroAmount());

    StorageV1 storage $ = _getStorageV1();
    Validator storage validator = _validator($, valAddr);
    _assertOperator(validator);

    $.entrypoint.depositCollateral{ value: msg.value }(validator.pubKey);

    emit CollateralDeposited(valAddr, msg.value);
  }

  /// @inheritdoc IValidatorManager
  function withdrawCollateral(address valAddr, address recipient, uint256 amount) external {
    require(amount > 0, StdError.ZeroAmount());

    StorageV1 storage $ = _getStorageV1();
    Validator storage validator = _validator($, valAddr);
    _assertOperator(validator);

    $.entrypoint.withdrawCollateral(
      validator.pubKey,
      amount,
      recipient,
      $.epochFeeder.clock() + $.globalValidatorConfig.collateralWithdrawalDelay.toUint48()
    );

    emit CollateralWithdrawn(valAddr, amount);
  }

  /// @inheritdoc IValidatorManager
  function unjailValidator(address valAddr) external {
    StorageV1 storage $ = _getStorageV1();
    Validator storage validator = _validator($, valAddr);
    _assertOperator(validator);

    $.entrypoint.unjail(validator.pubKey);

    emit ValidatorUnjailed(valAddr);
  }

  /// @inheritdoc IValidatorManager
  function updateOperator(address operator) external {
    require(operator != address(0), StdError.InvalidParameter('operator'));
    address valAddr = _msgSender();

    StorageV1 storage $ = _getStorageV1();
    _assertValidatorExists($, valAddr);
    if (valAddr != operator) _assertValidatorNotExists($, operator);

    $.validators[$.indexByValAddr[valAddr]].operator = operator;

    emit OperatorUpdated(valAddr, operator);
  }

  /// @inheritdoc IValidatorManager
  function updateRewardRecipient(address valAddr, address rewardRecipient) external {
    require(rewardRecipient != address(0), StdError.InvalidParameter('rewardRecipient'));

    StorageV1 storage $ = _getStorageV1();
    Validator storage validator = _validator($, valAddr);
    _assertOperator(validator);

    $.validators[$.indexByValAddr[valAddr]].rewardRecipient = rewardRecipient;

    emit RewardRecipientUpdated(valAddr, _msgSender(), rewardRecipient);
  }

  /// @inheritdoc IValidatorManager
  function updateMetadata(address valAddr, bytes calldata metadata) external {
    require(metadata.length > 0, StdError.InvalidParameter('metadata'));

    StorageV1 storage $ = _getStorageV1();
    Validator storage validator = _validator($, valAddr);
    _assertOperator(validator);

    $.validators[$.indexByValAddr[valAddr]].metadata = metadata;

    emit MetadataUpdated(valAddr, _msgSender(), metadata);
  }

  /// @inheritdoc IValidatorManager
  function updateRewardConfig(address valAddr, UpdateRewardConfigRequest calldata request) external {
    StorageV1 storage $ = _getStorageV1();
    Validator storage validator = _validator($, valAddr);
    _assertOperator(validator);

    GlobalValidatorConfig memory globalConfig = $.globalValidatorConfig;
    require(
      globalConfig.minimumCommissionRates[globalConfig.minimumCommissionRates.length - 1].amount
        <= request.commissionRate && request.commissionRate <= MAX_COMMISSION_RATE,
      StdError.InvalidParameter('commissionRate')
    );

    uint96 epoch = $.epochFeeder.epoch();
    if (globalConfig.commissionRateUpdateDelay == 0) {
      validator.rewardConfig.commissionRates.push(EpochCheckpoint({ epoch: epoch, amount: request.commissionRate }));
    } else {
      uint96 epochToUpdate = epoch + globalConfig.commissionRateUpdateDelay;

      validator.rewardConfig.pendingCommissionRate = request.commissionRate;
      validator.rewardConfig.pendingCommissionRateUpdateEpoch = epochToUpdate;
    }

    emit RewardConfigUpdated(valAddr, _msgSender());
  }

  /// @inheritdoc IValidatorManager
  function setGlobalValidatorConfig(SetGlobalValidatorConfigRequest calldata request) external onlyOwner {
    _setGlobalValidatorConfig(_getStorageV1(), request);
  }

  /// @inheritdoc IValidatorManager
  function setEpochFeeder(IEpochFeeder epochFeeder_) external onlyOwner {
    _setEpochFeeder(_getStorageV1(), epochFeeder_);
  }

  /// @inheritdoc IValidatorManager
  function setEntrypoint(IConsensusValidatorEntrypoint entrypoint_) external onlyOwner {
    _setEntrypoint(_getStorageV1(), entrypoint_);
  }

  // ===================================== INTERNAL FUNCTIONS ===================================== //

  function _searchCheckpoint(EpochCheckpoint[] storage history, uint96 epoch)
    internal
    view
    returns (EpochCheckpoint memory)
  {
    EpochCheckpoint memory last = history[history.length - 1];
    if (last.epoch <= epoch) return last;

    uint256 left = 0;
    uint256 right = history.length - 1;
    uint256 target = 0;

    while (left <= right) {
      uint256 mid = left + (right - left) / 2;
      if (history[mid].epoch <= epoch) {
        target = mid;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    return history[target];
  }

  function _searchCheckpoint(TWABCheckpoint[] storage history, uint48 timestamp)
    internal
    view
    returns (TWABCheckpoint memory)
  {
    TWABCheckpoint memory last = history[history.length - 1];
    if (last.lastUpdate <= timestamp) return last;

    uint256 left = 0;
    uint256 right = history.length - 1;
    uint256 target = 0;

    while (left <= right) {
      uint256 mid = left + (right - left) / 2;
      if (history[mid].lastUpdate <= timestamp) {
        target = mid;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    return history[target];
  }

  function _staked(address valAddr, address staker, uint48 timestamp) internal view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    TWABCheckpoint[] storage history = _validator($, valAddr).delegationLog[staker];
    if (history.length == 0) return 0;

    TWABCheckpoint memory last = _searchCheckpoint(history, timestamp);
    return last.amount;
  }

  function _stakedTWAB(address valAddr, address staker, uint48 timestamp) internal view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    TWABCheckpoint[] storage history = _validator($, valAddr).delegationLog[staker];
    if (history.length == 0) return 0;

    TWABCheckpoint memory last = _searchCheckpoint(history, timestamp);
    return (last.amount * (timestamp - last.lastUpdate)).toUint208();
  }

  function _unstaking(address valAddr, address staker, uint48 timestamp) internal view returns (uint256, uint256) {
    StorageV1 storage $ = _getStorageV1();
    _assertValidatorExists($, valAddr);

    LibRedeemQueue.Queue storage unstakeQueue = _validator($, valAddr).unstakeQueue;

    uint256 offset = unstakeQueue.indexes[staker].offset;
    (uint256 newOffset, bool found) = unstakeQueue.searchIndexOffset(staker, type(uint256).max, timestamp);

    uint256 claimable = 0;
    uint256 nonClaimable = 0;

    if (found) {
      for (uint256 i = offset; i < newOffset; i++) {
        claimable += unstakeQueue.requestAmount(i);
      }
    }

    for (uint256 i = found ? newOffset : offset; i < unstakeQueue.indexes[staker].size; i++) {
      nonClaimable += unstakeQueue.requestAmount(i);
    }

    return (claimable, nonClaimable);
  }

  function _totalDelegation(address valAddr, uint48 timestamp) internal view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    TWABCheckpoint[] storage history = _validator($, valAddr).totalDelegations;
    if (history.length == 0) return 0;

    return _searchCheckpoint(history, timestamp).amount;
  }

  function _totalDelegationTWAB(address valAddr, uint48 timestamp) internal view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    TWABCheckpoint[] storage history = _validator($, valAddr).totalDelegations;
    if (history.length == 0) return 0;

    TWABCheckpoint memory last = _searchCheckpoint(history, timestamp);
    return last.twab + (last.amount * (timestamp - last.lastUpdate)).toUint208();
  }

  function _stake(StorageV1 storage $, address valAddr, address recipient, uint256 amount, uint48 now_) internal {
    Validator storage validator = _validator($, valAddr);
    _pushTWABCheckpoint(validator.delegationLog[recipient], amount, now_, _addAmount);
    _pushTWABCheckpoint(validator.totalDelegations, amount, now_, _addAmount);
  }

  function _unstake(StorageV1 storage $, address valAddr, address recipient, uint256 amount) internal {
    uint48 now_ = $.epochFeeder.clock();

    Validator storage validator = _validator($, valAddr);
    _pushTWABCheckpoint(validator.delegationLog[recipient], amount, now_, _subAmount);
    _pushTWABCheckpoint(validator.totalDelegations, amount, now_, _subAmount);
  }

  function _addAmount(uint256 x, uint256 y) internal pure returns (uint256) {
    return x + y;
  }

  function _subAmount(uint256 x, uint256 y) internal pure returns (uint256) {
    return x - y;
  }

  function _pushEpochCheckpoint(
    EpochCheckpoint[] storage history,
    uint256 amount,
    uint96 epoch,
    function (uint256, uint256) returns (uint256) nextAmountFunc
  ) internal {
    if (history.length == 0) {
      // NOTE: it is impossible to push sub amount to the history
      history.push(EpochCheckpoint({ epoch: epoch, amount: amount }));
    } else {
      EpochCheckpoint memory last = history[history.length - 1];
      if (last.epoch != epoch) {
        history.push(EpochCheckpoint({ epoch: epoch, amount: amount }));
      } else {
        history[history.length - 1].amount = nextAmountFunc(last.amount, amount);
      }
    }
  }

  function _pushTWABCheckpoint(
    TWABCheckpoint[] storage history,
    uint256 amount,
    uint48 now_,
    function (uint256, uint256) returns (uint256) nextAmountFunc
  ) internal {
    if (history.length == 0) {
      history.push(TWABCheckpoint({ amount: amount, twab: 0, lastUpdate: now_ }));
    } else {
      TWABCheckpoint memory last = history[history.length - 1];
      history.push(
        TWABCheckpoint({
          amount: nextAmountFunc(last.amount, amount),
          twab: (last.amount * (now_ - last.lastUpdate)).toUint208(),
          lastUpdate: now_
        })
      );
    }
  }

  function _setEpochFeeder(StorageV1 storage $, IEpochFeeder epochFeeder_) internal {
    require(address(epochFeeder_).code.length > 0, StdError.InvalidParameter('epochFeeder'));
    $.epochFeeder = epochFeeder_;

    emit EpochFeederUpdated(epochFeeder_);
  }

  function _setEntrypoint(StorageV1 storage $, IConsensusValidatorEntrypoint entrypoint_) internal {
    require(address(entrypoint_).code.length > 0, StdError.InvalidParameter('entrypoint'));
    $.entrypoint = entrypoint_;

    emit EntrypointUpdated(entrypoint_);
  }

  function _setGlobalValidatorConfig(StorageV1 storage $, SetGlobalValidatorConfigRequest memory request) internal {
    require(
      0 <= request.minimumCommissionRate && request.minimumCommissionRate <= MAX_COMMISSION_RATE,
      StdError.InvalidParameter('minimumCommissionRate')
    );
    require(request.commissionRateUpdateDelay > 0, StdError.InvalidParameter('commissionRateUpdateDelay'));
    require(request.initialValidatorDeposit >= 0, StdError.InvalidParameter('initialValidatorDeposit'));
    require(request.unstakeCooldown >= 0, StdError.InvalidParameter('unstakeCooldown'));
    require(request.redelegationCooldown >= 0, StdError.InvalidParameter('redelegationCooldown'));
    require(request.collateralWithdrawalDelay >= 0, StdError.InvalidParameter('collateralWithdrawalDelay'));

    uint96 epoch = $.epochFeeder.epoch();
    $.globalValidatorConfig.minimumCommissionRates.push(
      EpochCheckpoint({ epoch: epoch, amount: request.minimumCommissionRate })
    );
    $.globalValidatorConfig.commissionRateUpdateDelay = request.commissionRateUpdateDelay;
    $.globalValidatorConfig.initialValidatorDeposit = request.initialValidatorDeposit;
    $.globalValidatorConfig.unstakeCooldown = request.unstakeCooldown;
    $.globalValidatorConfig.redelegationCooldown = request.redelegationCooldown;
    $.globalValidatorConfig.collateralWithdrawalDelay = request.collateralWithdrawalDelay;

    emit GlobalValidatorConfigUpdated();
  }

  function _validator(StorageV1 storage $, address valAddr) internal view returns (Validator storage) {
    uint256 index = $.indexByValAddr[valAddr];
    require(index != 0, StdError.InvalidParameter('valAddr'));
    return $.validators[index];
  }

  function _assertValidatorExists(StorageV1 storage $, address valAddr) internal view {
    require($.indexByValAddr[valAddr] != 0, StdError.InvalidParameter('valAddr'));
  }

  function _assertValidatorNotExists(StorageV1 storage $, address valAddr) internal view {
    require($.indexByValAddr[valAddr] == 0, StdError.InvalidParameter('valAddr'));
  }

  function _assertOperator(Validator storage validator) internal view {
    require(validator.operator == _msgSender(), StdError.Unauthorized());
  }

  // ========== UUPS ========== //

  function _authorizeUpgrade(address) internal override onlyOwner { }
}
