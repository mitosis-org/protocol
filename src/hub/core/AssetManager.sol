// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { PausableUpgradeable } from '@ozu-v5/utils/PausableUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { AssetManagerStorageV1 } from './storage/AssetManagerStorageV1.sol';
import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { IEOLVault } from '../../interfaces/hub/core/IEOLVault.sol';
import { IMitosisLedger } from '../../interfaces/hub/core/IMitosisLedger.sol';

contract AssetManager is PausableUpgradeable, Ownable2StepUpgradeable, AssetManagerStorageV1 {
  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_) public initializer {
    __Pausable_init();
    __Ownable2Step_init();
    _transferOwnership(owner_);
  }

  function deposit(uint256 chainId, address branchAsset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    address hubAsset = $.hubAssets[branchAsset][chainId];
    // temp: There is no hubAsset check logic. because it's validae on Branch side.
    IHubAsset(hubAsset).mint(to, amount);
    $.mitosisLedger.recordDeposit(chainId, hubAsset, amount);
  }

  function deallocateEOL(uint256 eolId, uint256 amount) external {
    _getStorageV1().mitosisLedger.recordDeallocateEOL(eolId, amount);
  }

  function settleYield(uint256 chainId, uint256 eolId, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    // temp: hmm how about store the chainId to EOLVault? it seems good
    IEOLVault eolVault = $.eolVaults[eolId];
    address hubAsset = eolVault.asset();

    IHubAsset(hubAsset).mint(address(this), amount);
    $.mitosisLedger.recordDeposit(chainId, hubAsset, amount);

    // temp: What kind of value to be store to MitosisLedger?
    IHubAsset(hubAsset).transfer(address(eolVault), amount);
  }

  function settleLoss(uint256 chainId, uint256 eolId, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    IEOLVault eolVault = $.eolVaults[eolId];
    address hubAsset = eolVault.asset();

    // temp: Trying to decrease the value of miAsset by increasing the denominator.
    // Sending to address(0) is weird. This indicates a burn, and in this case, the
    // totalSupply should be reduced.
    // It should be sent to a specific address instead.
    // mitosis_hub_asset_locker...
    IHubAsset(hubAsset).mint(address(0), amount);
    // temp: seems not good
    $.mitosisLedger.recordDeposit(chainId, hubAsset, amount);
  }

  function settleExtraRewards(uint256 chainId, uint256 eolId, address reward, uint256 amount) external {
    // temp:
    //    1. mint
    //     1-1. If it doesn't exist, should we deploy the HubAsset? The reward
    //          asset hasn't been checked for initialization, so~
    //    2. send to RewardTreasury
  }
}
