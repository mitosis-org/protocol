// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { Time } from '@oz-v5/utils/types/Time.sol';

import { IAssetManager } from '../../interfaces/hub/core/IAssetManager.sol';
import { IAssetManagerEntrypoint } from '../../interfaces/hub/core/IAssetManagerEntrypoint.sol';
import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { IEOLVault } from '../../interfaces/hub/eol/vault/IEOLVault.sol';
import { Pausable } from '../../lib/Pausable.sol';
import { StdError } from '../../lib/StdError.sol';
import { AssetManagerStorageV1 } from './AssetManagerStorageV1.sol';

contract AssetManager is IAssetManager, Pausable, Ownable2StepUpgradeable, AssetManagerStorageV1 {
  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_, address optOutQueue_) public initializer {
    __Pausable_init();
    __Ownable2Step_init();
    _transferOwnership(owner_);

    StorageV1 storage $ = _getStorageV1();

    _setOptOutQueue($, optOutQueue_);
  }

  //=========== NOTE: ASSET FUNCTIONS ===========//

  function deposit(uint256 chainId, address branchAsset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertBranchAssetPairExist($, chainId, branchAsset);

    address hubAsset = $.hubAssets[chainId][branchAsset];
    _mint($, chainId, hubAsset, to, amount);

    emit Deposited(chainId, hubAsset, to, amount);
  }

  function depositWithOptIn(uint256 chainId, address branchAsset, address to, address eolVault, uint256 amount)
    external
  {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertBranchAssetPairExist($, chainId, branchAsset);
    _assertEOLInitialized($, chainId, eolVault);

    address hubAsset = $.hubAssets[chainId][branchAsset];
    require(hubAsset == IEOLVault(eolVault).asset(), IAssetManager__InvalidEOLVault(eolVault, hubAsset));

    _mint($, chainId, hubAsset, address(this), amount);

    IHubAsset(hubAsset).approve(eolVault, amount);
    IEOLVault(eolVault).deposit(amount, to);

    emit DepositedWithOptIn(chainId, hubAsset, to, eolVault, amount);
  }

  function redeem(uint256 chainId, address hubAsset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    require(to != address(0), StdError.ZeroAddress('to'));
    require(amount != 0, StdError.ZeroAmount());

    address branchAsset = $.branchAssets[hubAsset][chainId];
    _assertBranchAssetPairExist($, chainId, branchAsset);

    _burn($, chainId, hubAsset, _msgSender(), amount);
    $.entrypoint.redeem(chainId, branchAsset, to, amount);

    emit Redeemed(chainId, hubAsset, to, amount);
  }

  //=========== NOTE: EOL FUNCTIONS ===========//

  /// @dev only strategist
  function allocateEOL(uint256 chainId, address eolVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyStrategist($, eolVault);
    _assertEOLInitialized($, chainId, eolVault);

    uint256 idle = _eolIdle($, eolVault);
    require(amount <= idle, IAssetManager__EOLInsufficient(eolVault));

    $.entrypoint.allocateEOL(chainId, eolVault, amount);
    $.eolStates[eolVault].allocation += amount;

    emit EOLAllocated(chainId, eolVault, amount);
  }

  /// @dev only entrypoint
  function deallocateEOL(uint256 chainId, address eolVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);

    $.eolStates[eolVault].allocation -= amount;

    emit EOLDeallocated(chainId, eolVault, amount);
  }

  /// @dev only strategist
  function reserveEOL(address eolVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyStrategist($, eolVault);

    uint256 idle = _eolIdle($, eolVault);
    require(amount <= idle, IAssetManager__EOLInsufficient(eolVault));

    $.optOutQueue.sync(eolVault, amount);
  }

  /// @dev only entrypoint
  function settleYield(uint256 chainId, address eolVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);

    // Increase EOLVault's shares value.
    address asset = IEOLVault(eolVault).asset();
    _mint($, chainId, asset, address(eolVault), amount);

    emit RewardSettled(chainId, eolVault, asset, amount);
  }

  /// @dev only entrypoint
  function settleLoss(uint256 chainId, address eolVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);

    // Decrease EOLVault's shares value.
    address asset = IEOLVault(eolVault).asset();
    _burn($, chainId, asset, eolVault, amount);

    emit LossSettled(chainId, eolVault, asset, amount);
  }

  /// @dev only entrypoint
  function settleExtraRewards(uint256 chainId, address eolVault, address branchReward, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyEntrypoint($);
    _assertBranchAssetPairExist($, chainId, branchReward);
    _assertRewardHandlerSet($);

    address hubReward = $.hubAssets[chainId][branchReward];
    _mint($, chainId, hubReward, address(this), amount);
    emit RewardSettled(chainId, eolVault, hubReward, amount);

    IHubAsset(hubReward).approve(address($.rewardHandler), amount);
    $.rewardHandler.handleReward(eolVault, hubReward, amount, bytes(''));
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function initializeAsset(uint256 chainId, address hubAsset) external onlyOwner {
    _assertOnlyContract(hubAsset, 'hubAsset');

    StorageV1 storage $ = _getStorageV1();

    address branchAsset = $.branchAssets[hubAsset][chainId];
    _assertBranchAssetPairExist($, chainId, branchAsset);

    $.entrypoint.initializeAsset(chainId, branchAsset);
    emit AssetInitialized(hubAsset, chainId, branchAsset);
  }

  function initializeEOL(uint256 chainId, address eolVault) external onlyOwner {
    _assertOnlyContract(eolVault, 'eolVault');

    StorageV1 storage $ = _getStorageV1();

    address hubAsset = IEOLVault(eolVault).asset();
    address branchAsset = $.branchAssets[hubAsset][chainId];
    _assertBranchAssetPairExist($, chainId, branchAsset);

    _assertEOLNotInitialized($, chainId, eolVault);
    $.eolInitialized[chainId][eolVault] = true;

    $.entrypoint.initializeEOL(chainId, eolVault, branchAsset);
    emit EOLInitialized(hubAsset, chainId, eolVault, branchAsset);
  }

  function setAssetPair(address hubAsset, uint256 branchChainId, address branchAsset) external onlyOwner {
    _assertOnlyContract(address(hubAsset), 'hubAsset');

    // TODO(ray): handle already initialized asset through initializeAsset.
    //
    // https://github.com/mitosis-org/protocol/pull/23#discussion_r1728680943
    StorageV1 storage $ = _getStorageV1();
    $.branchAssets[hubAsset][branchChainId] = branchAsset;
    $.hubAssets[branchChainId][branchAsset] = hubAsset;
    emit AssetPairSet(hubAsset, branchChainId, branchAsset);
  }

  function setEntrypoint(address entrypoint_) external onlyOwner {
    _setEntrypoint(_getStorageV1(), entrypoint_);
  }

  function setOptOutQueue(address optOutQueue_) external onlyOwner {
    _setOptOutQueue(_getStorageV1(), optOutQueue_);
  }

  function setRewardHandler(address rewardHandler_) external onlyOwner {
    _setRewardHandler(_getStorageV1(), rewardHandler_);
  }

  function setStrategist(address eolVault, address strategist) external onlyOwner {
    _setStrategist(_getStorageV1(), eolVault, strategist);
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _mint(StorageV1 storage $, uint256 chainId, address asset, address account, uint256 amount) internal {
    IHubAsset(asset).mint(account, amount);
    $.collateralPerChain[chainId][asset] += amount;
  }

  function _burn(StorageV1 storage $, uint256 chainId, address asset, address account, uint256 amount) internal {
    IHubAsset(asset).burn(account, amount);
    $.collateralPerChain[chainId][asset] -= amount;
  }

  //=========== NOTE: ASSERTIONS ===========//

  function _assertOnlyContract(address addr, string memory paramName) internal view {
    require(addr.code.length > 0, StdError.InvalidParameter(paramName));
  }
}
