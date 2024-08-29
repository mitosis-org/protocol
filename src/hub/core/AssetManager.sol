// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { PausableUpgradeable } from '@ozu-v5/utils/PausableUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { Time } from '@oz-v5/utils/types/Time.sol';

import { AssetManagerStorageV1 } from './storage/AssetManagerStorageV1.sol';
import { IAssetManager } from '../../interfaces/hub/core/IAssetManager.sol';
import { IAssetManagerEntrypoint } from '../../interfaces/hub/core/IAssetManagerEntrypoint.sol';
import { IEOLRewardManager } from '../../interfaces/hub/eol/IEOLRewardManager.sol';
import { IEOLVault } from '../../interfaces/hub/eol/IEOLVault.sol';
import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { IMitosisLedger } from '../../interfaces/hub/core/IMitosisLedger.sol';
import { StdError } from '../../lib/StdError.sol';

contract AssetManager is IAssetManager, PausableUpgradeable, Ownable2StepUpgradeable, AssetManagerStorageV1 {
  //=========== NOTE: EVENT DEFINITIONS ===========//

  event AssetInitialized(uint256 indexed chainId, address asset);
  event EOLInitialized(uint256 indexed chainId, address eolVault, address asset);

  event Deposited(uint256 indexed chainId, address indexed asset, address indexed to, uint256 amount);
  event Redeemed(uint256 indexed chainId, address indexed asset, address indexed to, uint256 amount);

  event YieldSettled(uint256 indexed chainId, address indexed eolVault, uint256 amount);
  event LossSettled(uint256 indexed chainId, address indexed eolVault, uint256 amount);
  event ExtraRewardsSettled(uint256 indexed chainId, address indexed eolVault, address indexed reward, uint256 amount);

  event EOLAllocated(uint256 indexed chainId, address indexed eolVault, uint256 amount);
  event EOLDeallocated(uint256 indexed chainId, address indexed eolVault, uint256 amount);

  event AssetPairSet(address hubAsset, uint256 branchChainId, address branchAsset);
  event EOLRewardManagerSet(address rewardManager);

  event EntrypointSet(address entrypoint);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error AssetManager__EOLInsufficient(address eolVault);
  error AssetManager__EOLRewardManagerNotSet();
  error AssetManager__BranchAssetPairNotExist(address asset);

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

    _assertBranchAssetPairExist($, chainId, branchAsset);
    _assertOnlyEntrypoint($);

    address hubAsset = $.hubAssets[chainId][branchAsset];
    _mint($, chainId, hubAsset, to, amount);

    emit Deposited(chainId, hubAsset, to, amount);
  }

  function redeem(uint256 chainId, address hubAsset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    if (to == address(0)) revert StdError.ZeroAddress('to');
    if (amount == 0) revert StdError.ZeroAmount();

    address branchAsset = $.branchAssets[hubAsset][chainId];
    _assertBranchAssetPairExist($, chainId, branchAsset);

    _burn($, chainId, hubAsset, _msgSender(), amount);
    $.entrypoint.redeem(chainId, branchAsset, to, amount);

    emit Redeemed(chainId, hubAsset, to, amount);
  }

  //=========== NOTE: EOL FUNCTIONS ===========//

  function allocateEOL(uint256 chainId, address eolVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyStrategist($, eolVault);

    IMitosisLedger.EOLAmountState memory state = $.mitosisLedger.eolAmountState(eolVault);
    if (state.idle < amount) {
      revert AssetManager__EOLInsufficient(eolVault);
    }

    $.entrypoint.allocateEOL(chainId, eolVault, amount);
    $.mitosisLedger.recordAllocateEOL(eolVault, amount);

    emit EOLAllocated(chainId, eolVault, amount);
  }

  function deallocateEOL(uint256 chainId, address eolVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);

    $.mitosisLedger.recordDeallocateEOL(eolVault, amount);

    emit EOLDeallocated(chainId, eolVault, amount);
  }

  function settleYield(uint256 chainId, address eolVault, uint256 amount) external {
    _assertOnlyEntrypoint(_getStorageV1());

    // TODO(ray): we should give a specific portion of yield to hubAsset holders too.
    _increaseEOLShareValue(eolVault, amount);

    emit YieldSettled(chainId, eolVault, amount);
  }

  function settleLoss(uint256 chainId, address eolVault, uint256 amount) external {
    _assertOnlyEntrypoint(_getStorageV1());

    _decreaseEOLShareValue(eolVault, amount);

    emit LossSettled(chainId, eolVault, amount);
  }

  function settleExtraRewards(uint256 chainId, address eolVault, address reward, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertBranchAssetPairExist($, chainId, reward);
    _assertEOLRewardManagerSet($);
    _assertOnlyEntrypoint($);

    address hubAsset = $.hubAssets[chainId][reward];
    _mint($, chainId, reward, address(this), amount);

    IHubAsset(hubAsset).approve(address($.rewardManager), amount);
    $.rewardManager.routeReward(eolVault, hubAsset, amount);

    emit ExtraRewardsSettled(chainId, eolVault, reward, amount);
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function initializeAsset(uint256 chainId, address hubAsset) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    address branchAsset = $.branchAssets[hubAsset][chainId];
    _assertBranchAssetPairExist($, chainId, branchAsset);

    $.entrypoint.initializeAsset(chainId, branchAsset);
    emit AssetInitialized(chainId, branchAsset);
  }

  function setAssetPair(address hubAsset, uint256 branchChainId, address branchAsset) external onlyOwner {
    // TODO(ray): handle already initialized asset through initializeAsset.
    //
    // https://github.com/mitosis-org/protocol/pull/23#discussion_r1728680943
    StorageV1 storage $ = _getStorageV1();
    $.branchAssets[hubAsset][branchChainId] = branchAsset;
    $.hubAssets[branchChainId][branchAsset] = hubAsset;
    emit AssetPairSet(hubAsset, branchChainId, branchAsset);
  }

  function setEntrypoint(IAssetManagerEntrypoint entrypoint) external onlyOwner {
    _getStorageV1().entrypoint = entrypoint;
    emit EntrypointSet(address(entrypoint));
  }

  function setEOLRewardManager(IEOLRewardManager rewardManager) external onlyOwner {
    _getStorageV1().rewardManager = rewardManager;
    emit EOLRewardManagerSet(address(rewardManager));
  }

  function initializeEOL(uint256 chainId, address eolVault) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    address hubAsset = IEOLVault(eolVault).asset();
    address branchAsset = $.branchAssets[hubAsset][chainId];
    _assertBranchAssetPairExist($, chainId, branchAsset);

    $.entrypoint.initializeEOL(chainId, eolVault, branchAsset);
    emit EOLInitialized(chainId, eolVault, branchAsset);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _increaseEOLShareValue(address eolVault, uint256 assets) internal {
    IHubAsset(IEOLVault(eolVault).asset()).mint(eolVault, assets);
  }

  function _decreaseEOLShareValue(address eolVault, uint256 assets) internal {
    IHubAsset(IEOLVault(eolVault).asset()).burn(eolVault, assets);
  }

  function _mint(StorageV1 storage $, uint256 chainId, address asset, address account, uint256 amount) internal {
    IHubAsset(asset).mint(account, amount);
    $.mitosisLedger.recordDeposit(chainId, asset, amount);
  }

  function _burn(StorageV1 storage $, uint256 chainId, address asset, address account, uint256 amount) internal {
    IHubAsset(asset).burn(account, amount);
    $.mitosisLedger.recordWithdraw(chainId, asset, amount);
  }

  function _assertOnlyEntrypoint(StorageV1 storage $) internal view {
    if (_msgSender() != address($.entrypoint)) revert StdError.InvalidAddress('entrypoint');
  }

  function _assertBranchAssetPairExist(StorageV1 storage $, uint256 chainId, address branchAsset) internal view {
    if ($.hubAssets[chainId][branchAsset] == address(0)) revert AssetManager__BranchAssetPairNotExist(branchAsset);
  }

  function _assertOnlyStrategist(StorageV1 storage $, address eolVault) internal view {
    if (_msgSender() != $.mitosisLedger.eolStrategist(eolVault)) revert StdError.InvalidAddress('strategist');
  }

  function _assertEOLRewardManagerSet(StorageV1 storage $) internal view {
    if (address($.rewardManager) == address(0)) revert AssetManager__EOLRewardManagerNotSet();
  }
}
