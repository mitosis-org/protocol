// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { IValidatorManager } from '../../interfaces/hub/core/IValidatorManager.sol';
import { IConsensusValidatorEntrypoint } from '../../interfaces/hub/consensus-layer/IConsensusValidatorEntrypoint.sol';
import { LibSecp256k1 } from '../../lib/LibSecp256k1.sol';
import { StdError } from '../../lib/StdError.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

contract ValidatorManagerStorageV1 {
  using ERC7201Utils for string;

  struct DelegationLog {
    uint256 amount;
    uint208 twab;
    uint48 lastUpdate;
  }

  struct Redelegation {
    address fromValidator;
    address toValidator;
    uint256 amount;
  }

  struct Validator {
    address validator;
    address operator;
    bytes pubKey;
    uint256 totalDelegated;
  }

  struct StorageV1 {
    IConsensusValidatorEntrypoint entrypoint;
    Validator[] validators;
    mapping(address validator => uint256 index) indexedByValidator;
    mapping(address validator => mapping(address staker => DelegationLog[])) delegationHistory;
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

contract ValidatorManager is IValidatorManager, ValidatorManagerStorageV1, ContextUpgradeable {
  using SafeCast for uint256;

  constructor() {
    _disableInitializers();
  }

  function initialize(IConsensusValidatorEntrypoint entrypoint) external initializer {
    StorageV1 storage $ = _getStorageV1();
    _setEntrypoint($, entrypoint);
    // 0 index is reserved for empty slot
    {
      Validator memory empty;
      $.validators.push(empty);
    }
  }

  function clock() public view returns (uint48) {
    return block.timestamp.toUint48();
  }

  function stake(address valAddr, address recipient) external payable {
    require(msg.value > 0, StdError.InvalidParameter('msg.value'));

    StorageV1 storage $ = _getStorageV1();
    _assertValidatorExists($, valAddr);

    _stake($, valAddr, recipient, msg.value);
  }

  function unstake(address valAddr, uint256 amount) external {
    require(amount > 0, StdError.InvalidParameter('amount'));

    StorageV1 storage $ = _getStorageV1();
    _assertValidatorExists($, valAddr);

    DelegationLog[] storage history = $.delegationHistory[valAddr][_msgSender()];
    require(history.length > 0, StdError.InvalidParameter('history'));

    _unstake($, valAddr, amount);
  }

  function redelegate(address fromValAddr, address toValAddr, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();
    Validator memory fromInfo = _validatorInfo($, fromValAddr);
    Validator memory toInfo = _validatorInfo($, toValAddr);

    _unstake($, fromValAddr, amount);
    _stake($, toValAddr, _msgSender(), amount);
  }

  function join(bytes calldata valKey) external payable {
    address valAddr = _msgSender();

    // verify the valKey is valid and corresponds to the caller
    LibSecp256k1.verifyCmpPubkeyWithAddress(valKey, valAddr);

    StorageV1 storage $ = _getStorageV1();
    _assertValidatorNotExists($, valAddr);

    $.validators.push(Validator({ validator: valAddr, operator: valAddr, pubKey: valKey, totalDelegated: 0 }));
    $.indexedByValidator[valAddr] = $.validators.length - 1;
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

    $.validators[$.indexedByValidator[valAddr]].operator = operator;
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
      // FIXME: apply 3 epoch delay
      clock() + 1 days
    );
  }

  function unjail(address valAddr) external {
    StorageV1 storage $ = _getStorageV1();
    Validator memory info = _validatorInfo($, valAddr);
    _assertOperator(info);

    $.entrypoint.unjail(info.pubKey);
  }

  function setEntrypoint(IConsensusValidatorEntrypoint entrypoint) external {
    _setEntrypoint(_getStorageV1(), entrypoint);
  }

  function _stake(StorageV1 storage $, address valAddr, address recipient, uint256 amount) internal {
    DelegationLog[] storage history = $.delegationHistory[valAddr][recipient];
    if (history.length > 0) {
      DelegationLog memory last = history[history.length - 1];
      history.push(
        DelegationLog({
          amount: last.amount + msg.value,
          twab: (last.amount * (clock() - last.lastUpdate)).toUint208(),
          lastUpdate: clock()
        })
      );
    } else {
      history.push(DelegationLog({ amount: msg.value, twab: 0, lastUpdate: clock() }));
    }

    $.validators[$.indexedByValidator[valAddr]].totalDelegated += msg.value;
  }

  function _unstake(StorageV1 storage $, address valAddr, uint256 amount) internal {
    DelegationLog memory last = history[history.length - 1];
    require(amount <= last.amount, StdError.InvalidParameter('amount'));

    history.push(
      DelegationLog({
        amount: last.amount - amount,
        twab: (last.amount * (clock() - last.lastUpdate)).toUint208(),
        lastUpdate: clock()
      })
    );

    $.validators[$.indexedByValidator[valAddr]].totalDelegated -= amount;
  }

  function _setEntrypoint(StorageV1 storage $, IConsensusValidatorEntrypoint entrypoint) internal {
    require(address(entrypoint).code.length > 0, StdError.InvalidParameter('entrypoint'));
    $.entrypoint = entrypoint;
  }

  function _validatorInfo(StorageV1 storage $, address valAddr) internal view returns (Validator memory) {
    uint256 index = $.indexedByValidator[valAddr];
    require(index != 0, StdError.InvalidParameter('valAddr'));
    return $.validators[index];
  }

  function _assertValidatorExists(StorageV1 storage $, address valAddr) internal view {
    require($.indexedByValidator[valAddr] != 0, StdError.InvalidParameter('valAddr'));
  }

  function _assertValidatorNotExists(StorageV1 storage $, address valAddr) internal view {
    require($.indexedByValidator[valAddr] == 0, StdError.InvalidParameter('valAddr'));
  }

  function _assertOperator(Validator memory info) internal view {
    require(info.operator == _msgSender(), StdError.Unauthorized());
  }
}
