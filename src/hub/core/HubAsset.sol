// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { ERC20Upgradeable } from '@ozu-v5/token/ERC20/ERC20Upgradeable.sol';

import { StdError } from '../../lib/StdError.sol';
import { HubAssetStorageV1 } from './HubAssetStorageV1.sol';

contract HubAsset is Ownable2StepUpgradeable, ERC20Upgradeable, HubAssetStorageV1 {
  constructor() {
    _disableInitializers();
  }

  function initialize(
    address owner_,
    address supplyManager_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_
  ) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner_);
    __ERC20_init(name_, symbol_);
    _getStorageV1().supplyManager = supplyManager_;
    StorageV1 storage $ = _getStorageV1();
    $.supplyManager = supplyManager_;
    $.decimals = decimals_;
  }

  modifier onlySupplyManager() {
    require(_msgSender() == _getStorageV1().supplyManager, StdError.Unauthorized());
    _;
  }

  function decimals() public view override returns (uint8) {
    return _getStorageV1().decimals;
  }

  function supplyManager() external view returns (address) {
    return _getStorageV1().supplyManager;
  }

  function mint(address account, uint256 value) external onlySupplyManager {
    _mint(account, value);
  }

  function burn(address account, uint256 value) external onlySupplyManager {
    _burn(account, value);
  }

  function setSupplyManager(address supplyManager_) external onlyOwner {
    _getStorageV1().supplyManager = supplyManager_;
  }
}
