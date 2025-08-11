// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IERC20 } from '@oz/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz/token/ERC20/utils/SafeERC20.sol';
import { Ownable2StepUpgradeable } from '@ozu/access/Ownable2StepUpgradeable.sol';

import { IMitosisVaultEntrypoint } from '../interfaces/branch/IMitosisVaultEntrypoint.sol';
import { IMitosisVaultVLF, VLFAction } from '../interfaces/branch/IMitosisVaultVLF.sol';
import { IVLFStrategyExecutor } from '../interfaces/branch/strategy/IVLFStrategyExecutor.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';
import { Pausable } from '../lib/Pausable.sol';
import { StdError } from '../lib/StdError.sol';

abstract contract MitosisVaultVLF is IMitosisVaultVLF, Pausable, Ownable2StepUpgradeable {
  using ERC7201Utils for string;
  using SafeERC20 for IERC20;

  struct VLFInfo {
    bool initialized;
    address asset;
    address strategyExecutor;
    uint256 availableLiquidity;
    mapping(VLFAction => bool) isHalted;
  }

  struct VLFStorageV1 {
    mapping(address hubVLF => VLFInfo) matrices;
  }

  string private constant _NAMESPACE = 'mitosis.storage.MitosisVault.VLF.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getVLFStorageV1() private view returns (VLFStorageV1 storage $) {
    bytes32 slot = _slot;
    assembly {
      $.slot := slot
    }
  }

  //=========== NOTE: View ===========//

  function isVLFActionHalted(address hubVLF, VLFAction action) external view returns (bool) {
    return _isVLFHalted(_getVLFStorageV1(), hubVLF, action);
  }

  function isVLFInitialized(address hubVLF) external view returns (bool) {
    return _isVLFInitialized(_getVLFStorageV1(), hubVLF);
  }

  function availableVLF(address hubVLF) external view returns (uint256) {
    return _getVLFStorageV1().matrices[hubVLF].availableLiquidity;
  }

  function vlfStrategyExecutor(address hubVLF) external view returns (address) {
    return _getVLFStorageV1().matrices[hubVLF].strategyExecutor;
  }

  function quoteDepositWithSupplyVLF(address asset, address to, address hubVLF, uint256 amount)
    external
    view
    returns (uint256)
  {
    return IMitosisVaultEntrypoint(entrypoint()).quoteDepositWithSupplyVLF(asset, to, hubVLF, amount);
  }

  function quoteDeallocateVLF(address hubVLF, uint256 amount) external view returns (uint256) {
    return IMitosisVaultEntrypoint(entrypoint()).quoteDeallocateVLF(hubVLF, amount);
  }

  function quoteSettleVLFYield(address hubVLF, uint256 amount) external view returns (uint256) {
    return IMitosisVaultEntrypoint(entrypoint()).quoteSettleVLFYield(hubVLF, amount);
  }

  function quoteSettleVLFLoss(address hubVLF, uint256 amount) external view returns (uint256) {
    return IMitosisVaultEntrypoint(entrypoint()).quoteSettleVLFLoss(hubVLF, amount);
  }

  function quoteSettleVLFExtraRewards(address hubVLF, address reward, uint256 amount)
    external
    view
    returns (uint256)
  {
    return IMitosisVaultEntrypoint(entrypoint()).quoteSettleVLFExtraRewards(hubVLF, reward, amount);
  }

  //=========== NOTE: Asset ===========//

  function _deposit(address asset, address to, uint256 amount) internal virtual;

  function _assertAssetInitialized(address asset) internal view virtual;

  function entrypoint() public view virtual returns (address);

  function depositWithSupplyVLF(address asset, address to, address hubVLF, uint256 amount)
    external
    payable
    whenNotPaused
  {
    _deposit(asset, to, amount);

    VLFStorageV1 storage $ = _getVLFStorageV1();
    _assertVLFInitialized($, hubVLF);
    require(asset == $.matrices[hubVLF].asset, IMitosisVaultVLF__InvalidVLF(hubVLF, asset));

    IMitosisVaultEntrypoint(entrypoint()).depositWithSupplyVLF{ value: msg.value }(asset, to, hubVLF, amount);

    emit VLFDepositedWithSupply(asset, to, hubVLF, amount);
  }

  //=========== NOTE: VLF Lifecycle ===========//

  function initializeVLF(address hubVLF, address asset) external whenNotPaused {
    require(entrypoint() == _msgSender(), StdError.Unauthorized());

    VLFStorageV1 storage $ = _getVLFStorageV1();

    _assertVLFNotInitialized($, hubVLF);
    _assertAssetInitialized(asset);

    $.matrices[hubVLF].initialized = true;
    $.matrices[hubVLF].asset = asset;

    emit VLFInitialized(hubVLF, asset);
  }

  function allocateVLF(address hubVLF, uint256 amount) external payable whenNotPaused {
    require(entrypoint() == _msgSender(), StdError.Unauthorized());

    VLFStorageV1 storage $ = _getVLFStorageV1();
    _assertVLFInitialized($, hubVLF);

    $.matrices[hubVLF].availableLiquidity += amount;

    emit VLFAllocated(hubVLF, amount);
  }

  function deallocateVLF(address hubVLF, uint256 amount) external payable whenNotPaused {
    VLFStorageV1 storage $ = _getVLFStorageV1();

    _assertVLFInitialized($, hubVLF);
    _assertOnlyStrategyExecutor($, hubVLF);

    $.matrices[hubVLF].availableLiquidity -= amount;
    IMitosisVaultEntrypoint(entrypoint()).deallocateVLF{ value: msg.value }(hubVLF, amount);

    emit VLFDeallocated(hubVLF, amount);
  }

  function fetchVLF(address hubVLF, uint256 amount) external whenNotPaused {
    VLFStorageV1 storage $ = _getVLFStorageV1();

    _assertVLFInitialized($, hubVLF);
    _assertOnlyStrategyExecutor($, hubVLF);
    _assertNotHalted($, hubVLF, VLFAction.FetchVLF);

    VLFInfo storage vlfInfo = $.matrices[hubVLF];

    vlfInfo.availableLiquidity -= amount;
    IERC20(vlfInfo.asset).safeTransfer(vlfInfo.strategyExecutor, amount);

    emit VLFFetched(hubVLF, amount);
  }

  function returnVLF(address hubVLF, uint256 amount) external whenNotPaused {
    VLFStorageV1 storage $ = _getVLFStorageV1();

    _assertVLFInitialized($, hubVLF);
    _assertOnlyStrategyExecutor($, hubVLF);

    VLFInfo storage vlfInfo = $.matrices[hubVLF];

    vlfInfo.availableLiquidity += amount;
    IERC20(vlfInfo.asset).safeTransferFrom(vlfInfo.strategyExecutor, address(this), amount);

    emit VLFReturned(hubVLF, amount);
  }

  function settleVLFYield(address hubVLF, uint256 amount) external payable whenNotPaused {
    VLFStorageV1 storage $ = _getVLFStorageV1();

    _assertVLFInitialized($, hubVLF);
    _assertOnlyStrategyExecutor($, hubVLF);

    IMitosisVaultEntrypoint(entrypoint()).settleVLFYield{ value: msg.value }(hubVLF, amount);

    emit VLFYieldSettled(hubVLF, amount);
  }

  function settleVLFLoss(address hubVLF, uint256 amount) external payable whenNotPaused {
    VLFStorageV1 storage $ = _getVLFStorageV1();

    _assertVLFInitialized($, hubVLF);
    _assertOnlyStrategyExecutor($, hubVLF);

    IMitosisVaultEntrypoint(entrypoint()).settleVLFLoss{ value: msg.value }(hubVLF, amount);

    emit VLFLossSettled(hubVLF, amount);
  }

  function settleVLFExtraRewards(address hubVLF, address reward, uint256 amount)
    external
    payable
    whenNotPaused
  {
    VLFStorageV1 storage $ = _getVLFStorageV1();

    _assertVLFInitialized($, hubVLF);
    _assertOnlyStrategyExecutor($, hubVLF);
    _assertAssetInitialized(reward);
    require(reward != $.matrices[hubVLF].asset, StdError.InvalidAddress('reward'));

    IERC20(reward).safeTransferFrom(_msgSender(), address(this), amount);
    IMitosisVaultEntrypoint(entrypoint()).settleVLFExtraRewards{ value: msg.value }(hubVLF, reward, amount);

    emit VLFExtraRewardsSettled(hubVLF, reward, amount);
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function haltVLF(address hubVLF, VLFAction action) external onlyOwner {
    VLFStorageV1 storage $ = _getVLFStorageV1();
    _assertVLFInitialized($, hubVLF);
    return _haltVLF($, hubVLF, action);
  }

  function resumeVLF(address hubVLF, VLFAction action) external onlyOwner {
    VLFStorageV1 storage $ = _getVLFStorageV1();
    _assertVLFInitialized($, hubVLF);
    return _resumeVLF($, hubVLF, action);
  }

  function setVLFStrategyExecutor(address hubVLF, address strategyExecutor_) external onlyOwner {
    VLFStorageV1 storage $ = _getVLFStorageV1();
    VLFInfo storage vlfInfo = $.matrices[hubVLF];

    _assertVLFInitialized($, hubVLF);

    if (vlfInfo.strategyExecutor != address(0)) {
      // NOTE: no way to check if every extra rewards are settled.
      bool drained = IVLFStrategyExecutor(vlfInfo.strategyExecutor).totalBalance() == 0
        && IVLFStrategyExecutor(vlfInfo.strategyExecutor).storedTotalBalance() == 0;
      require(drained, IMitosisVaultVLF__StrategyExecutorNotDrained(hubVLF, vlfInfo.strategyExecutor));
    }

    require(
      hubVLF == IVLFStrategyExecutor(strategyExecutor_).hubVLF(),
      StdError.InvalidId('vlfStrategyExecutor.hubVLF')
    );
    require(
      address(this) == address(IVLFStrategyExecutor(strategyExecutor_).vault()),
      StdError.InvalidAddress('vlfStrategyExecutor.vault')
    );
    require(
      vlfInfo.asset == address(IVLFStrategyExecutor(strategyExecutor_).asset()),
      StdError.InvalidAddress('vlfStrategyExecutor.asset')
    );

    vlfInfo.strategyExecutor = strategyExecutor_;
    emit VLFStrategyExecutorSet(hubVLF, strategyExecutor_);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _isVLFHalted(VLFStorageV1 storage $, address hubVLF, VLFAction action)
    internal
    view
    returns (bool)
  {
    return $.matrices[hubVLF].isHalted[action];
  }

  function _haltVLF(VLFStorageV1 storage $, address hubVLF, VLFAction action) internal {
    $.matrices[hubVLF].isHalted[action] = true;
    emit VLFHalted(hubVLF, action);
  }

  function _resumeVLF(VLFStorageV1 storage $, address hubVLF, VLFAction action) internal {
    $.matrices[hubVLF].isHalted[action] = false;
    emit VLFResumed(hubVLF, action);
  }

  function _assertNotHalted(VLFStorageV1 storage $, address hubVLF, VLFAction action) internal view {
    require(!_isVLFHalted($, hubVLF, action), StdError.Halted());
  }

  function _isVLFInitialized(VLFStorageV1 storage $, address hubVLF) internal view returns (bool) {
    return $.matrices[hubVLF].initialized;
  }

  function _assertVLFInitialized(VLFStorageV1 storage $, address hubVLF) internal view {
    require(_isVLFInitialized($, hubVLF), IMitosisVaultVLF__VLFNotInitialized(hubVLF));
  }

  function _assertVLFNotInitialized(VLFStorageV1 storage $, address hubVLF) internal view {
    require(!_isVLFInitialized($, hubVLF), IMitosisVaultVLF__VLFAlreadyInitialized(hubVLF));
  }

  function _assertOnlyStrategyExecutor(VLFStorageV1 storage $, address hubVLF) internal view {
    require(_msgSender() == $.matrices[hubVLF].strategyExecutor, StdError.Unauthorized());
  }
}
