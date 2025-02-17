// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { EnumerableMap } from '@oz-v5/utils/structs/EnumerableMap.sol';

import { IConsensusValidatorEntrypoint } from '../../interfaces/hub/consensus-layer/IConsensusValidatorEntrypoint.sol';
import { IEpochFeeder } from '../../interfaces/hub/core/IEpochFeeder.sol';
import { IValidatorManager } from '../../interfaces/hub/core/IValidatorManager.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
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

  struct Redelegation {
    uint96 epoch;
    uint256 total;
    EnumerableMap.AddressToUintMap logs;
    bool applied;
  }

  struct ValidatorStat {
    TWABCheckpoint[] totalDelegations;
    EpochCheckpoint[] totalPendingRedelegations;
    uint96 lastUpdatedEpoch;
  }

  struct Validator {
    address validator;
    address operator;
    bytes pubKey;
    ValidatorStat stat;
  }

  struct StorageV1 {
    IEpochFeeder epochFeeder;
    IConsensusValidatorEntrypoint entrypoint;
    uint256[] validatorIndexes;
    mapping(uint256 index => Validator) validators;
    mapping(address valAddr => uint256 index) indexByValAddr;
    mapping(address valAddr => mapping(address staker => TWABCheckpoint[])) delegationHistory;
    mapping(address staker => mapping(address toValAddr => Redelegation[])) redelegationHistory;
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

  // NOTE: This is a temporary limit. It will be revised in the next version.
  uint256 public constant MAX_REDELEGATION_COUNT = 100;

  constructor() {
    _disableInitializers();
  }

  function initialize(address initialOwner, IEpochFeeder epochFeeder, IConsensusValidatorEntrypoint entrypoint)
    external
    initializer
  {
    __Ownable_init(initialOwner);

    StorageV1 storage $ = _getStorageV1();
    _setEpochFeeder($, epochFeeder);
    _setEntrypoint($, entrypoint);

    // 0 index is reserved for empty slot
    $.validatorIndexes.push(0);
  }

  function validators() external view returns (address[] memory) {
    StorageV1 storage $ = _getStorageV1();
    address[] memory validators_ = new address[]($.validatorIndexes.length - 1);
    for (uint256 i = 1; i < $.validatorIndexes.length; i++) {
      validators_[i - 1] = $.validators[i].validator;
    }

    return validators_;
  }

  function staked(address valAddr, address staker) external view returns (uint256) {
    return _staked(valAddr, staker, _getStorageV1().epochFeeder.clock());
  }

  function staked(address valAddr, address staker, uint48 timestamp) external view returns (uint256) {
    return _staked(valAddr, staker, timestamp);
  }

  function stakedTWAB(address valAddr, address staker) external view returns (uint256) {
    return _stakedTWAB(valAddr, staker, _getStorageV1().epochFeeder.clock());
  }

  function stakedTWAB(address valAddr, address staker, uint48 timestamp) external view returns (uint256) {
    return _stakedTWAB(valAddr, staker, timestamp);
  }

  function redelegations(address toValAddr, address staker, uint96 epoch)
    external
    view
    returns (RedelegationsResponse[] memory)
  {
    Redelegation[] storage history = _getStorageV1().redelegationHistory[staker][toValAddr];
    if (history.length == 0) return new RedelegationsResponse[](0); // no redelegation history

    (Redelegation storage redelegation, bool found) = _searchRedelegationLog(history, epoch);
    if (!found || redelegation.epoch > epoch) return new RedelegationsResponse[](0); // no redelegation on this epoch

    // Convert the redelegation logs to response array
    RedelegationsResponse[] memory responses = new RedelegationsResponse[](redelegation.logs.length());
    for (uint256 i = 0; i < redelegation.logs.length(); i++) {
      (address fromValAddr, uint256 amount) = redelegation.logs.at(i);
      responses[i] = RedelegationsResponse({
        epoch: redelegation.epoch,
        fromValAddr: fromValAddr,
        toValAddr: toValAddr,
        staker: staker,
        amount: amount
      });
    }

    return responses;
  }

  function totalDelegation(address valAddr) external view returns (uint256) {
    return _totalDelegation(valAddr, _getStorageV1().epochFeeder.clock());
  }

  function totalDelegation(address valAddr, uint48 timestamp) external view returns (uint256) {
    return _totalDelegation(valAddr, timestamp);
  }

  function totalDelegationTWAB(address valAddr) external view returns (uint256) {
    return _totalDelegationTWAB(valAddr, _getStorageV1().epochFeeder.clock());
  }

  function totalDelegationTWAB(address valAddr, uint48 timestamp) external view returns (uint256) {
    return _totalDelegationTWAB(valAddr, timestamp);
  }

  function totalPendingRedelegation(address valAddr) external view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    ValidatorStat memory stat = _validatorInfo($, valAddr).stat;
    if (stat.totalPendingRedelegations.length == 0) return 0;

    EpochCheckpoint[] memory history = stat.totalPendingRedelegations;
    EpochCheckpoint memory last = history[history.length - 1];
    if (stat.lastUpdatedEpoch == last.epoch) return last.amount;

    return 0;
  }

  function totalPendingRedelegation(address valAddr, uint96 epoch) external view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    ValidatorStat memory stat = _validatorInfo($, valAddr).stat;
    if (stat.totalPendingRedelegations.length == 0) return 0;

    EpochCheckpoint[] memory history = stat.totalPendingRedelegations;
    uint256 left = 0;
    uint256 right = history.length - 1;
    uint256 target = 0;

    while (left <= right) {
      uint256 mid = left + (right - left) / 2;
      if (history[mid].epoch == epoch) {
        return history[mid].amount;
      } else if (history[mid].epoch < epoch) {
        target = mid;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    return 0;
  }

  function stake(address valAddr, address recipient) external payable {
    require(msg.value > 0, StdError.InvalidParameter('msg.value'));

    StorageV1 storage $ = _getStorageV1();
    _assertValidatorExists($, valAddr);

    _updatePendingDelegation($, valAddr);
    _applyRedelegation($, valAddr, recipient);

    _stake($, valAddr, recipient, msg.value, $.epochFeeder.clock());
  }

  function unstake(address valAddr, uint256 amount) external {
    require(amount > 0, StdError.InvalidParameter('amount'));

    StorageV1 storage $ = _getStorageV1();
    _assertValidatorExists($, valAddr);

    TWABCheckpoint[] storage history = $.delegationHistory[valAddr][_msgSender()];
    require(history.length > 0, StdError.InvalidParameter('history'));

    _updatePendingDelegation($, valAddr);
    _applyRedelegation($, valAddr, _msgSender());

    _unstake($, valAddr, amount);
  }

  function redelegate(address fromValAddr, address toValAddr, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();
    _assertValidatorExists($, fromValAddr);
    _assertValidatorExists($, toValAddr);

    _updatePendingDelegation($, fromValAddr);
    _updatePendingDelegation($, toValAddr);

    _applyRedelegation($, fromValAddr, _msgSender());
    _applyRedelegation($, toValAddr, _msgSender());

    _unstake($, fromValAddr, amount);
    _pushRedelegation($, fromValAddr, toValAddr, _msgSender(), amount);

    _pushEpochCheckpoint(
      $.validators[$.indexByValAddr[fromValAddr]].stat.totalPendingRedelegations,
      amount,
      $.epochFeeder.epoch(),
      _addAmount
    );
  }

  function cancelRedelegation(address fromValAddr, address toValAddr, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();
    _assertValidatorExists($, fromValAddr);
    _assertValidatorExists($, toValAddr);

    _updatePendingDelegation($, fromValAddr);
    _updatePendingDelegation($, toValAddr);

    _applyRedelegation($, fromValAddr, _msgSender());
    _applyRedelegation($, toValAddr, _msgSender());

    uint96 epoch = $.epochFeeder.epoch();

    Redelegation[] storage history = $.redelegationHistory[_msgSender()][fromValAddr];
    require(history.length > 0, StdError.InvalidParameter('history'));

    Redelegation storage last = history[history.length - 1];
    require(last.epoch == epoch && !last.applied, StdError.InvalidParameter('history'));

    uint256 redelegationAmount = last.logs.get(fromValAddr);
    require(redelegationAmount > amount, StdError.InvalidParameter('amount'));

    if (redelegationAmount == amount) last.logs.remove(fromValAddr);
    else last.logs.set(fromValAddr, redelegationAmount - amount);
    last.total -= amount;

    _stake($, fromValAddr, _msgSender(), amount, $.epochFeeder.clock());

    _pushEpochCheckpoint(
      $.validators[$.indexByValAddr[fromValAddr]].stat.totalPendingRedelegations, amount, epoch, _subAmount
    );
  }

  function join(bytes calldata valKey) external payable {
    address valAddr = _msgSender();

    // verify the valKey is valid and corresponds to the caller
    LibSecp256k1.verifyCmpPubkeyWithAddress(valKey, valAddr);

    StorageV1 storage $ = _getStorageV1();
    _assertValidatorNotExists($, valAddr);

    uint256 valIndex = $.validatorIndexes.length;
    $.validatorIndexes.push(valIndex);

    Validator storage val = $.validators[valIndex];
    val.validator = valAddr;
    val.operator = valAddr;
    val.pubKey = valKey;
    val.stat.lastUpdatedEpoch = $.epochFeeder.epoch();

    $.indexByValAddr[valAddr] = valIndex;
    $.entrypoint.registerValidator{ value: msg.value }(valKey, valAddr);
  }

  /// @dev Operator must be following:
  /// 1. validator == operator
  /// 2. validator != operator && operator is not a validator
  function updateOperator(address operator) external {
    require(operator != address(0), StdError.InvalidParameter('operator'));
    address valAddr = _msgSender();

    StorageV1 storage $ = _getStorageV1();
    Validator memory info = _validatorInfo($, valAddr);
    require(
      valAddr == operator || (valAddr != operator && info.operator == address(0)), StdError.InvalidParameter('operator')
    );

    $.validators[$.indexByValAddr[valAddr]].operator = operator;
  }

  function depositCollateral(address valAddr) external payable {
    require(msg.value > 0, StdError.InvalidParameter('msg.value'));

    StorageV1 storage $ = _getStorageV1();
    Validator memory info = _validatorInfo($, valAddr);
    _assertOperator(info);

    $.entrypoint.depositCollateral{ value: msg.value }(info.pubKey);
  }

  function withdrawCollateral(address valAddr, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();
    Validator memory info = _validatorInfo($, valAddr);
    _assertOperator(info);

    $.entrypoint.withdrawCollateral(
      info.pubKey,
      amount,
      _msgSender(),
      // interval() returns 1 epoch's interval
      $.epochFeeder.clock() + ($.epochFeeder.interval() * 3)
    );
  }

  function unjail(address valAddr) external {
    StorageV1 storage $ = _getStorageV1();
    Validator memory info = _validatorInfo($, valAddr);
    _assertOperator(info);

    $.entrypoint.unjail(info.pubKey);
  }

  function setEpochFeeder(IEpochFeeder epochFeeder) external {
    _setEpochFeeder(_getStorageV1(), epochFeeder);
  }

  function setEntrypoint(IConsensusValidatorEntrypoint entrypoint) external {
    _setEntrypoint(_getStorageV1(), entrypoint);
  }

  // ===================================== INTERNAL FUNCTIONS ===================================== //

  function _searchCheckpoint(TWABCheckpoint[] memory history, uint48 timestamp)
    internal
    pure
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

  function _searchRedelegationLog(Redelegation[] storage history, uint96 epoch)
    internal
    view
    returns (Redelegation storage, bool found)
  {
    // Binary search for the redelegation at or before the target epoch
    uint256 left = 0;
    uint256 right = history.length - 1;
    uint256 target = right;

    while (left <= right) {
      uint256 mid = (left + right) / 2;
      if (history[mid].epoch == epoch) {
        target = mid;
        break;
      } else if (history[mid].epoch < epoch) {
        target = mid;
        left = mid + 1;
      } else {
        if (mid == 0) return (history[0], false);
        right = mid - 1;
      }
    }

    return (history[target], true);
  }

  function _staked(address valAddr, address staker, uint48 timestamp) internal view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    // prevent future lookup
    require(timestamp > $.epochFeeder.clock(), StdError.InvalidParameter('timestamp'));

    uint96 epoch = $.epochFeeder.epochAt(timestamp);

    // TODO: debug this
    // NOTE: no need to lookup the redelegation history here because it is already applied to the delegation history
    TWABCheckpoint[] memory history = $.delegationHistory[valAddr][staker];
    if (history.length == 0) return 0;

    TWABCheckpoint memory last = _searchCheckpoint(history, timestamp);

    // check if there are any pending redelegation
    Redelegation[] storage redelegations_ = $.redelegationHistory[staker][valAddr];
    if (redelegations_.length > 0) {
      Redelegation storage lastRedelegation = redelegations_[redelegations_.length - 1];
      if (lastRedelegation.epoch < epoch && !lastRedelegation.applied) {
        last.amount += lastRedelegation.total;
      }
    }

    return last.amount;
  }

  function _stakedTWAB(address valAddr, address staker, uint48 timestamp) internal view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    TWABCheckpoint[] memory history = $.delegationHistory[valAddr][staker];
    if (history.length == 0) return 0;

    TWABCheckpoint memory last = _searchCheckpoint(history, timestamp);

    Redelegation[] storage redelegations_ = $.redelegationHistory[staker][valAddr];
    if (redelegations_.length > 0) {
      Redelegation storage lastRedelegation = redelegations_[redelegations_.length - 1];
      if (lastRedelegation.epoch < $.epochFeeder.epochAt(timestamp) && !lastRedelegation.applied) {
        uint48 nextEpochTime = $.epochFeeder.epochToTime(lastRedelegation.epoch + 1);
        if (nextEpochTime <= timestamp) {
          last.twab += ((last.amount + lastRedelegation.total) * (nextEpochTime - last.lastUpdate)).toUint208();
          last.amount += lastRedelegation.total;
          last.lastUpdate = nextEpochTime;
        }
      }
    }

    last.twab += (last.amount * (timestamp - last.lastUpdate)).toUint208();

    return last.twab;
  }

  function _totalDelegation(address valAddr, uint48 timestamp) internal view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    ValidatorStat memory stat = _validatorInfo($, valAddr).stat;
    TWABCheckpoint memory last = _searchCheckpoint(stat.totalDelegations, timestamp);

    uint96 epoch = $.epochFeeder.epochAt(timestamp);
    if (stat.lastUpdatedEpoch < epoch) {
      uint48 epochTime = $.epochFeeder.epochToTime(epoch);
      if (epochTime <= timestamp) {
        EpochCheckpoint memory lastEpochCheckpoint =
          stat.totalPendingRedelegations[stat.totalPendingRedelegations.length - 1];
        // if the last epoch checkpoint is the same as the target epoch, add the amount to the total delegation
        if (lastEpochCheckpoint.epoch == epoch) last.amount += lastEpochCheckpoint.amount;
      }
    }

    return last.amount;
  }

  function _totalDelegationTWAB(address valAddr, uint48 timestamp) internal view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    ValidatorStat memory stat = _validatorInfo($, valAddr).stat;
    TWABCheckpoint memory last = _searchCheckpoint(stat.totalDelegations, timestamp);

    uint96 epoch = $.epochFeeder.epochAt(timestamp);
    if (stat.lastUpdatedEpoch < epoch) {
      uint48 epochTime = $.epochFeeder.epochToTime(epoch);
      if (epochTime <= timestamp) {
        last.twab += (last.amount * (epochTime - last.lastUpdate)).toUint208();

        EpochCheckpoint memory lastEpochCheckpoint =
          stat.totalPendingRedelegations[stat.totalPendingRedelegations.length - 1];
        // if the last epoch checkpoint is the same as the target epoch, add the amount to the total delegation
        if (lastEpochCheckpoint.epoch == epoch) last.amount += lastEpochCheckpoint.amount;
        last.lastUpdate = epochTime;
      }
    }

    last.twab += (last.amount * (timestamp - last.lastUpdate)).toUint208();

    return last.twab;
  }

  function _stake(StorageV1 storage $, address valAddr, address recipient, uint256 amount, uint48 now_) internal {
    _pushTWABCheckpoint($.delegationHistory[valAddr][recipient], amount, now_, _addAmount);
    _pushTWABCheckpoint($.validators[$.indexByValAddr[valAddr]].stat.totalDelegations, amount, now_, _addAmount);
  }

  function _unstake(StorageV1 storage $, address valAddr, uint256 amount) internal {
    TWABCheckpoint[] storage history = $.delegationHistory[valAddr][_msgSender()];
    TWABCheckpoint memory last = history[history.length - 1];
    require(amount <= last.amount, StdError.InvalidParameter('amount'));

    uint48 now_ = $.epochFeeder.clock();
    _pushTWABCheckpoint(history, amount, now_, _subAmount);
    _pushTWABCheckpoint($.validators[$.indexByValAddr[valAddr]].stat.totalDelegations, amount, now_, _subAmount);
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

  function _pushRedelegation(
    StorageV1 storage $,
    address fromValAddr,
    address toValAddr,
    address recipient,
    uint256 amount
  ) internal {
    uint96 epoch = $.epochFeeder.epoch();

    Redelegation[] storage history = $.redelegationHistory[recipient][toValAddr];
    if (history.length == 0) {
      history[0].epoch = epoch;
      history[0].total = amount;
      history[0].logs.set(fromValAddr, amount);
      history[0].applied = false;
    } else {
      Redelegation storage last = history[history.length - 1];

      // reuse the last redelegation if it's not applied due to the lack of history
      if (last.logs.length() == 0) {
        last.epoch = epoch;
        last.total = 0;
        last.applied = false;
      }

      if (last.epoch == epoch) {
        (bool exists, uint256 value) = last.logs.tryGet(fromValAddr);
        // revert if the number of redelegations exceeds the limit
        require(last.logs.length() + 1 > MAX_REDELEGATION_COUNT, StdError.Unauthorized());
        last.logs.set(fromValAddr, exists ? value + amount : amount);
        last.total += amount;
      } else {
        history[history.length].epoch = epoch;
        history[history.length].total = amount;
        history[history.length].logs.set(fromValAddr, amount);
        history[history.length].applied = false;
      }
    }
  }

  function _applyRedelegation(StorageV1 storage $, address valAddr, address recipient) internal {
    Redelegation[] storage history = $.redelegationHistory[recipient][valAddr];
    if (history.length > 0) {
      Redelegation storage last = history[history.length - 1];
      uint96 lastEpoch = last.epoch;

      if (lastEpoch < $.epochFeeder.epoch() && last.logs.length() > 0 && !last.applied) {
        last.applied = true;

        uint48 checkPoint = $.epochFeeder.epochToTime(lastEpoch + 1);
        _stake($, valAddr, recipient, last.total, checkPoint);
      }
    }
  }

  function _updatePendingDelegation(StorageV1 storage $, address valAddr) internal {
    uint96 epoch = $.epochFeeder.epoch();
    uint48 now_ = $.epochFeeder.clock();

    Validator memory info = _validatorInfo($, valAddr);
    if (info.stat.lastUpdatedEpoch >= epoch) return;

    ValidatorStat storage stat = $.validators[$.indexByValAddr[valAddr]].stat;

    EpochCheckpoint[] memory history = info.stat.totalPendingRedelegations;
    EpochCheckpoint memory last = history[history.length - 1];

    if (last.epoch == epoch) _pushTWABCheckpoint(stat.totalDelegations, last.amount, now_, _addAmount);
    stat.lastUpdatedEpoch = epoch;
  }

  function _setEpochFeeder(StorageV1 storage $, IEpochFeeder epochFeeder) internal {
    require(address(epochFeeder).code.length > 0, StdError.InvalidParameter('epochFeeder'));
    $.epochFeeder = epochFeeder;
  }

  function _setEntrypoint(StorageV1 storage $, IConsensusValidatorEntrypoint entrypoint) internal {
    require(address(entrypoint).code.length > 0, StdError.InvalidParameter('entrypoint'));
    $.entrypoint = entrypoint;
  }

  function _validatorInfo(StorageV1 storage $, address valAddr) internal view returns (Validator memory) {
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

  function _assertOperator(Validator memory info) internal view {
    require(info.operator == _msgSender(), StdError.Unauthorized());
  }

  // ========== UUPS ========== //

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
