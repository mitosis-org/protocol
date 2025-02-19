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

  struct EpochCheckpoint {
    uint96 epoch;
    uint160 amount;
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
  }

  struct StorageV1 {
    IEpochFeeder epochFeeder;
    IConsensusValidatorEntrypoint entrypoint;
    GlobalValidatorConfig globalValidatorConfig;
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
    validator.rewardConfig.commissionRates.push(
      EpochCheckpoint({ epoch: epoch, amount: request.commissionRate.toUint160() })
    );
    validator.metadata = request.metadata;

    $.indexByValAddr[valAddr] = valIndex;
    $.entrypoint.registerValidator{ value: msg.value }(valKey);

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
      validator.rewardConfig.commissionRates.push(
        EpochCheckpoint({ epoch: epoch, amount: request.commissionRate.toUint160() })
      );
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
      EpochCheckpoint({ epoch: epoch, amount: request.minimumCommissionRate.toUint160() })
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
