// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { PausableUpgradeable } from '@ozu-v5/utils/PausableUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { AssetManagerStorageV1 } from './storage/AssetManagerStorageV1.sol';
import { IRewardTreasury } from '../../interfaces/hub/core/IRewardTreasury.sol';
import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { IEOLVault } from '../../interfaces/hub/core/IEOLVault.sol';
import { IAssetManager } from '../../interfaces/hub/core/IAssetManager.sol';
import { IMitosisLedger } from '../../interfaces/hub/core/IMitosisLedger.sol';

contract AssetManager is IAssetManager, PausableUpgradeable, Ownable2StepUpgradeable, AssetManagerStorageV1 {
  //=========== NOTE: EVENT DEFINITIONS ===========//

  event AssetInitialized(uint256 indexed toChainId, address asset);
  event EOLInitialized(uint256 indexed toChainId, uint256 eolId, address asset);

  event Deposited(uint256 indexed fromChainId, address indexed asset, address indexed to, uint256 amount);
  event Redeemed(uint256 indexed toChainId, address indexed asset, address indexed to, uint256 amount);
  event Refunded(uint256 indexed toChainId, address indexed asset, address indexed to, uint256 amount);

  event YieldSettled(uint256 indexed fromChainId, uint256 indexed eolId, uint256 amount);
  event LossSettled(uint256 indexed fromChainId, uint256 indexed eolId, uint256 amount);
  event ExtraRewardsSettled(uint256 indexed fromChainId, uint256 indexed eolId, address indexed reward, uint256 amount);

  event EOLAllocated(uint256 indexed toChainId, uint256 indexed eolId, uint256 amount);
  event EOLDeallocated(uint256 indexed fromChainId, uint256 indexed eolId, uint256 amount);

  event AssetPairSset(address hubAsset, uint256 branchChainId, address branchAsset);
  event RewardTreasurySet(address rewardTreasury);

  event EntrypointSet(address entrypoint);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error AssetManager__EOLInsufficient(uint256 eolId);

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

  function deposit(uint256 chainId, address branchAsset, address to, address refundTo, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);

    address hubAsset = $.hubAssets[branchAsset][chainId];
    if (hubAsset != address(0)) {
      try this._mint(chainId, hubAsset, to, amount) {
        emit Deposited(chainId, asset, to, amount);
        return;
      } catch { }
    }

    $.entrypoint.refund(chainId, branchAsset, refundTo, amount);
    emit Refunded(chainId, asset, refundTo, amount);
  }

  function redeem(uint256 chainId, address branchAsset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertBranchAssetPairExist($, branchAsset);

    address hubAsset = $.hubAssets[branchAsset];
    _burn(chainId, hubAsset, to, amount);
    $.entrypoint.redeem(chainId, branchAsset, to, amount);

    emit Redeemed(chainId, hubAsset, to, amount);
  }

  //=========== NOTE: EOL FUNCTIONS ===========//

  function allocateEOL(uint256 chainId, uint256 eolId, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assetEolIdExist($, eolId);
    _assetOnlyStrategist($, eolId);

    (, uint256 idle,,) = $.mitosisLedger.eolAmountState(eolId);
    if (idle < amount) {
      revert AssetManager__EOLInsufficient(eolId);
    }
    $.mitosisLedger.recordAllocateEOL(eolId, amount);
    $.entrypoint.allocateEOL(chainId, eolId, amount);

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

    IEOLVault eolVault = IEOLVault($.mitosisLedger.eolVault(eolId));
    address hubAsset = eolVault.asset();

    _mint(hubAsset, chainId, address(this), amount);
    IHubAsset(hubAsset).transfer(address(eolVault), amount);

    emit YieldSettled(chainId, eolId, amount);
  }

  function settleLoss(uint256 chainId, uint256 eolId, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assetEolIdExist($, eolId);
    _assertOnlyEntrypoint($);

    IEOLVault eolVault = IEOLVault($.mitosisLedger.eolVault(eolId));
    address hubAsset = eolVault.asset();

    // temp: Trying to decrease the value of miAsset by increasing the denominator.
    IHubAsset(hubAsset).mint(address(this), amount);
    loss += amount; // ?
      // TODO(ray)

    emit LossSettled(chainId, eolId, amount);
  }

  function settleExtraRewards(uint256 chainId, uint256 eolId, address reward, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assetEolIdExist($, eolId);
    _assertOnlyEntrypoint($);

    address hubAsset = $.hubAssets[reward];
    if (hubAsset == address(0)) {
      // TODO(ray): deployment or ...
    } else {
      $.rewardTreasury.deposit(hubAsset, amount, block.timestamp);
    }

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
    emit AssetPairSset(hubAsset, branchChainId, branchAsset);
  }

  function setEntrypoint(AssetManagerEntrypoint entrypoint) external onlyOwner {
    _getStorageV1().entrypoint = entrypoint;
    emit EntrypointSet(entrypoint);
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
    address branchAsset = $.branchAssets[chainId][hubAsset];
    _assertBranchAssetPairExist($, branchAsset);

    $.entrypoint.initializeEOL(chainId, eolId, branchAsset);
    emit EOLInitialized(chainId, eolId, branchAsset);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _mint(uint256 chainId, address asset, address to, uint256 amount) internal {
    IHubAsset(asset).mint(to, amount);
    $.mitosisLedger.recordDeposit(chainId, asset, amount);
  }

  function _burn(uint256 chainId, address asset, address to, uint256 amount) internal {
    IHubAsset(asset).transferFrom(msg.sender, address(this));
    IHubAsset(asset).burn(amount);
    $.mitosisLedger.recordWithdraw(chainId, asset, amount);
  }

  function _assertOnlyEntrypoint(StorageV1 storage $) internal view {
    if (_msgSender() != address($.entrypoint)) revert StdError.InvalidAddress('entrypoint');
  }

  function _assetEolIdExist(StorageV1 storage $, uint256 eolId) internal view {
    if ($.mitosisLedger.eolVault(eolId) != address(0)) revert StdError.InvalidId('eolId');
  }

  function _assertBranchAssetPairExist(StorageV1 storage $, address branchAsset) internal view {
    if ($.hubAssets[branchAsset] != address(0)) revert StdError.InvalidAddress('branchAsset');
  }

  function _assetOnlyStrategist(StorageV1 storage $, uint256 eolId) internal view {
    if (_msgSender() != $.mitosisLedger.eolStrategist(eolId)) StdError.InvalidAddress('strategist');
  }
}
