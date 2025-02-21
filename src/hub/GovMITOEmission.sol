// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';

import { IGovMITO } from '../interfaces/hub/IGovMITO.sol';
import { IGovMITOEmission } from '../interfaces/hub/IGovMITOEmission.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';
import { StdError } from '../lib/StdError.sol';

contract GovMITOEmissionStorageV1 {
  using ERC7201Utils for string;

  struct ValidatorReward {
    uint256 amount;
    uint256 claimed;
  }

  struct StorageV1 {
    uint256 totalReserved;
    address validatorRewardRecipient;
    mapping(uint96 epoch => ValidatorReward) validatorReward;
  }

  string private constant _NAMESPACE = 'mitosis.storage.GovMITOEmission';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}

/// @title GovMITOEmission
/// @notice This contract is used to manage the emission of GovMITO
/// @dev This is very temporary contract. We need to think more about the design of the emission management.
contract GovMITOEmission is IGovMITOEmission, GovMITOEmissionStorageV1, UUPSUpgradeable, Ownable2StepUpgradeable {
  using SafeERC20 for IGovMITO;

  IGovMITO private immutable _govMITO;

  constructor(address govMITO_) {
    _govMITO = IGovMITO(govMITO_);

    _disableInitializers();
  }

  function initialize(address initialOwner) external initializer {
    __UUPSUpgradeable_init();
    __Ownable_init(initialOwner);
    __Ownable2Step_init();
  }

  /// @inheritdoc IGovMITOEmission
  function govMITO() external view returns (IGovMITO) {
    return _govMITO;
  }

  /// @inheritdoc IGovMITOEmission
  function totalReserved() external view returns (uint256) {
    return _getStorageV1().totalReserved;
  }

  /// @inheritdoc IGovMITOEmission
  function validatorReward(uint96 epoch) external view returns (uint256 amount, uint256 claimed) {
    StorageV1 storage $ = _getStorageV1();
    ValidatorReward memory reward = $.validatorReward[epoch];
    return (reward.amount, reward.claimed);
  }

  /// @inheritdoc IGovMITOEmission
  function validatorRewardRecipient() external view returns (address) {
    return _getStorageV1().validatorRewardRecipient;
  }

  /// @inheritdoc IGovMITOEmission
  function deposit() external payable onlyOwner {
    _govMITO.mint{ value: msg.value }(address(this));

    emit Deposited(msg.value);
  }

  /// @inheritdoc IGovMITOEmission
  function withdraw(uint256 amount) external onlyOwner {
    _govMITO.safeTransfer(_msgSender(), amount);

    emit Withdrawn(amount);
  }

  /// @inheritdoc IGovMITOEmission
  function requestValidatorReward(uint96 epoch, address recipient, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();
    ValidatorReward memory reward = $.validatorReward[epoch];
    require($.validatorRewardRecipient != address(0), StdError.Unauthorized());
    require(reward.amount >= reward.claimed + amount, NotEnoughReserve());

    $.totalReserved -= amount;
    $.validatorReward[epoch].claimed += amount;
    _govMITO.safeTransfer(recipient, amount);

    emit ValidatorRewardRequested(epoch, amount);
  }

  /// @inheritdoc IGovMITOEmission
  function reserveValidatorReward(uint96 epoch, uint256 amount) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    require(_govMITO.balanceOf(address(this)) >= $.totalReserved + amount, NotEnoughBalance());

    $.totalReserved += amount;
    $.validatorReward[epoch] = ValidatorReward({ amount: amount, claimed: 0 });

    emit ValidatorRewardReserved(epoch, amount);
  }

  /// @inheritdoc IGovMITOEmission
  function setValidatorRewardRecipient(address recipient) external onlyOwner {
    _setValidatorRewardRecipient(recipient);
  }

  function _setValidatorRewardRecipient(address recipient) internal {
    require(recipient != address(0), StdError.InvalidAddress('recipient'));

    StorageV1 storage $ = _getStorageV1();

    address previousRecipient = $.validatorRewardRecipient;
    $.validatorRewardRecipient = recipient;

    emit ValidatorRewardRecipientUpdated(previousRecipient, recipient);
  }

  // ================== UUPS ================== //

  function _authorizeUpgrade(address) internal view override onlyOwner { }
}
