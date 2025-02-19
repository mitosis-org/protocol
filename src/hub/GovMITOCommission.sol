// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';

import { IGovMITO } from '../interfaces/hub/IGovMITO.sol';
import { IGovMITOCommission } from '../interfaces/hub/IGovMITOCommission.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';
import { StdError } from '../lib/StdError.sol';

contract GovMITOCommissionStorageV1 {
  using ERC7201Utils for string;

  struct StorageV1 {
    mapping(address spender => uint256 capacity) capacity;
  }

  string private constant _NAMESPACE = 'mitosis.storage.GovMITOCommission';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}

/// @title GovMITOCommission
/// @notice This contract is used to manage the commission of GovMITO
/// @dev This is very temporary contract. We need to think more about the design of the commission management.
contract GovMITOCommission is IGovMITOCommission, GovMITOCommissionStorageV1, UUPSUpgradeable, Ownable2StepUpgradeable {
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

  function govMITO() external view returns (IGovMITO) {
    return _govMITO;
  }

  function capacity(address spender) external view returns (uint256) {
    return _getStorageV1().capacity[spender];
  }

  function deposit() external payable onlyOwner {
    _govMITO.mint{ value: msg.value }(address(this), msg.value);
  }

  function forceWithdraw(uint256 amount) external onlyOwner {
    _govMITO.safeTransfer(_msgSender(), amount);
  }

  function request(uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();
    require($.capacity[_msgSender()] >= amount, NotEnoughCapacity());

    $.capacity[_msgSender()] -= amount;
    _govMITO.safeTransfer(_msgSender(), amount);
  }

  function increaseCapacity(address spender, uint256 amount) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    $.capacity[spender] += amount;
  }

  function decreaseCapacity(address spender, uint256 amount) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    require($.capacity[spender] >= amount, NotEnoughCapacity());

    $.capacity[spender] -= amount;
  }

  // ================== UUPS ================== //

  function _authorizeUpgrade(address) internal view override onlyOwner { }
}
