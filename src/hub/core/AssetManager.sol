// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { PausableUpgradeable } from '@ozu-v5/utils/PausableUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { AssetManagerStorageV1 } from './storage/AssetManagerStorageV1.sol';
import { IRewardTreasury } from '../../interfaces/hub/core/IRewardTreasury.sol';
import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { IEOLVault } from '../../interfaces/hub/core/IEOLVault.sol';
import { IAssetManager } from '../../interfaces/hub/core/IAssetManager.sol';
import { IAssetManagerEntrypoint } from '../../interfaces/hub/core/IAssetManagerEntrypoint.sol';
import { IMitosisLedger } from '../../interfaces/hub/core/IMitosisLedger.sol';
import { StdError } from '../../lib/StdError.sol';

contract AssetManager is IAssetManager, PausableUpgradeable, Ownable2StepUpgradeable, AssetManagerStorageV1 {
  //=========== NOTE: EVENT DEFINITIONS ===========//

  event AssetInitialized(uint256 indexed toChainId, address asset);
  event EOLInitialized(uint256 indexed toChainId, uint256 eolId, address asset);

  event Deposited(uint256 indexed fromChainId, address indexed asset, address indexed to, uint256 amount);
  event Redeemed(uint256 indexed toChainId, address indexed asset, address indexed to, uint256 amount);

  event YieldSettled(uint256 indexed fromChainId, uint256 indexed eolId, uint256 amount);
  event LossSettled(uint256 indexed fromChainId, uint256 indexed eolId, uint256 amount);
  event ExtraRewardsSettled(uint256 indexed fromChainId, uint256 indexed eolId, address indexed reward, uint256 amount);

  event EOLAllocated(uint256 indexed toChainId, uint256 indexed eolId, uint256 amount);
  event EOLDeallocated(uint256 indexed fromChainId, uint256 indexed eolId, uint256 amount);

  event AssetPairSet(address hubAsset, uint256 branchChainId, address branchAsset);
  event RewardTreasurySet(address rewardTreasury);

  event EntrypointSet(address entrypoint);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error AssetManager__EOLInsufficient(uint256 eolId);
  error AssetManager__BranchAssetPairNotExist(address asset);
  error AssetManager__RewardTreasuryNotSet();

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_, address mitosisLedger_) public initializer {
    __Pausable_init();
    __Ownable2Step_init();
    _transferOwnership(owner_);
    _getStorageV1().mitosisLedger = IMitosisLedger(mitosisLedger_);
  }

  //=========== NOTE: ASSET FUNCTIONS ===========//

  function deposit(uint256 chainId, address branchAsset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertBranchAssetPairExist($, branchAsset);
    _assertOnlyEntrypoint($);

    address hubAsset = $.hubAssets[branchAsset];
    _mint($, chainId, hubAsset, to, amount);

    emit Deposited(chainId, hubAsset, to, amount);
  }

  function redeem(uint256 chainId, address hubAsset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    address branchAsset = $.branchAssets[hubAsset][chainId];
    _assertBranchAssetPairExist($, branchAsset);

    _burn($, chainId, hubAsset, amount);
    $.entrypoint.redeem(chainId, branchAsset, to, amount);

    emit Redeemed(chainId, hubAsset, to, amount);
  }

  //=========== NOTE: EOL FUNCTIONS ===========//

  function allocateEOL(uint256 chainId, uint256 eolId, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assetEolIdExist($, eolId);
    _assetOnlyStrategist($, eolId);

    IMitosisLedger.EOLAmountState memory state = $.mitosisLedger.eolAmountState(eolId);
    if (state.idle < amount) {
      revert AssetManager__EOLInsufficient(eolId);
    }

    $.entrypoint.allocateEOL(chainId, eolId, amount);
    $.mitosisLedger.recordAllocateEOL(eolId, amount);

    emit EOLAllocated(chainId, eolId, amount);
  }

  function deallocateEOL(uint256 chainId, uint256 eolId, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assetEolIdExist($, eolId);
    _assertOnlyEntrypoint($);

    $.mitosisLedger.recordDeallocateEOL(eolId, amount);

    emit EOLDeallocated(chainId, eolId, amount);
  }

  function settleYield(uint256 chainId, uint256 eolId, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assetEolIdExist($, eolId);
    _assertOnlyEntrypoint($);

    // TODO(ray): we should give a specific portion of yield to hubAsset holders too.
    _increaseEOLShareValue($, eolId, amount);

    emit YieldSettled(chainId, eolId, amount);
  }

  function settleLoss(uint256 chainId, uint256 eolId, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assetEolIdExist($, eolId);
    _assertOnlyEntrypoint($);

    _decreaseEOLShareValue($, eolId, amount);

    emit LossSettled(chainId, eolId, amount);
  }

  function settleExtraRewards(uint256 chainId, uint256 eolId, address reward, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assetEolIdExist($, eolId);
    _assetRewardTreasurySet($);
    _assertOnlyEntrypoint($);
    _assertBranchAssetPairExist($, reward);

    address hubAsset = $.hubAssets[reward];
    _mint($, chainId, reward, address(this), amount);

    IHubAsset(reward).approve(address($.rewardTreasury), amount);
    $.rewardTreasury.deposit(hubAsset, amount, Time.timestamp());

    emit ExtraRewardsSettled(chainId, eolId, reward, amount);
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function initializeAsset(uint256 chainId, address hubAsset) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    address branchAsset = $.branchAssets[hubAsset][chainId];
    _assertBranchAssetPairExist($, branchAsset);

    $.entrypoint.initializeAsset(chainId, branchAsset);
    emit AssetInitialized(chainId, branchAsset);
  }

  function setAssetPair(address hubAsset, uint256 branchChainId, address branchAsset) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    $.branchAssets[hubAsset][branchChainId] = branchAsset;
    $.hubAssets[branchAsset] = hubAsset;
    emit AssetPairSet(hubAsset, branchChainId, branchAsset);
  }

  function setEntrypoint(IAssetManagerEntrypoint entrypoint) external onlyOwner {
    _getStorageV1().entrypoint = entrypoint;
    emit EntrypointSet(address(entrypoint));
  }

  function setRewardTreasury(IRewardTreasury rewardTreasury) external onlyOwner {
    _getStorageV1().rewardTreasury = rewardTreasury;
    emit RewardTreasurySet(address(rewardTreasury));
  }

  function initializeEOL(uint256 chainId, uint256 eolId) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    _assetEolIdExist($, eolId);

    IEOLVault eolVault = IEOLVault($.mitosisLedger.eolVault(eolId));
    address hubAsset = eolVault.asset();
    address branchAsset = $.branchAssets[hubAsset][chainId];
    _assertBranchAssetPairExist($, branchAsset);

    $.entrypoint.initializeEOL(chainId, eolId, branchAsset);
    emit EOLInitialized(chainId, eolId, branchAsset);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _increaseEOLShareValue(StorageV1 storage $, uint256 eolId, uint256 assets) internal {
    IEOLVault eolVault = IEOLVault($.mitosisLedger.eolVault(eolId));
    IHubAsset(eolVault.asset()).mint(address(eolVault), assets);
  }

  function _decreaseEOLShareValue(StorageV1 storage $, uint256 eolId, uint256 assets) internal {
    IEOLVault eolVault = IEOLVault($.mitosisLedger.eolVault(eolId));
    IHubAsset(eolVault.asset()).burnFrom(address(eolVault), assets);
  }

  function _mint(StorageV1 storage $, uint256 chainId, address asset, address to, uint256 amount) internal {
    IHubAsset(asset).mint(to, amount);
    $.mitosisLedger.recordDeposit(chainId, asset, amount);
  }

  function _burn(StorageV1 storage $, uint256 chainId, address asset, uint256 amount) internal {
    IHubAsset(asset).burnFrom(msg.sender, amount);
    $.mitosisLedger.recordWithdraw(chainId, asset, amount);
  }

  function _assertOnlyEntrypoint(StorageV1 storage $) internal view {
    if (_msgSender() != address($.entrypoint)) revert StdError.InvalidAddress('entrypoint');
  }

  function _assetEolIdExist(StorageV1 storage $, uint256 eolId) internal view {
    if ($.mitosisLedger.eolVault(eolId) == address(0)) revert StdError.InvalidId('eolId');
  }

  function _assertBranchAssetPairExist(StorageV1 storage $, address branchAsset) internal view {
    if ($.hubAssets[branchAsset] == address(0)) revert AssetManager__BranchAssetPairNotExist(branchAsset);
  }

  function _assetOnlyStrategist(StorageV1 storage $, uint256 eolId) internal view {
    if (_msgSender() != $.mitosisLedger.eolStrategist(eolId)) revert StdError.InvalidAddress('strategist');
  }

  function _assetRewardTreasurySet(StorageV1 storage $) internal view {
    if (address($.rewardTreasury) == address(0)) revert AssetManager__RewardTreasuryNotSet();
  }
}
