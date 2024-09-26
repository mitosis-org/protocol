// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Address } from '@oz-v5/utils/Address.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { MitosisVaultStorageV1 } from '../branch/MitosisVaultStorageV1.sol';
import { IGlobalAccessControlManager } from '../interfaces/auth/IGlobalAccessControlManager.sol';
import { IMitosisVault } from '../interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '../interfaces/branch/IMitosisVaultEntrypoint.sol';
import { IStrategyExecutor } from '../interfaces/branch/strategy/IStrategyExecutor.sol';
import { StdError } from '../lib/StdError.sol';

// TODO(thai): add some view functions in MitosisVault

contract MitosisVault is IMitosisVault, Ownable2StepUpgradeable, MitosisVaultStorageV1 {
  using SafeERC20 for IERC20;
  using Address for address;

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() {
    _disableInitializers();
  }

  fallback() external payable {
    revert StdError.Unauthorized();
  }

  receive() external payable {
    revert StdError.Unauthorized();
  }

  function initialize(address owner_, address globalAccessControlManager_) public initializer {
    __Ownable2Step_init();
    _transferOwnership(owner_);

    require(globalAccessControlManager_.code.length > 0, StdError.InvalidParameter('globalAccessControlManager'));

    StorageV1 storage $ = _getStorageV1();
    $.globalAccessControlManager = IGlobalAccessControlManager(globalAccessControlManager_);
  }

  //=========== NOTE: VIEW FUNCTIONS ===========//

  function isAssetInitialized(address asset) external view returns (bool) {
    return _isAssetInitialized(_getStorageV1(), asset);
  }

  function isEOLInitialized(address hubEOLVault) external view returns (bool) {
    return _isEOLInitialized(_getStorageV1(), hubEOLVault);
  }

  function availableEOL(address hubEOLVault) external view returns (uint256) {
    return _getStorageV1().eols[hubEOLVault].availableEOL;
  }

  function entrypoint() external view returns (IMitosisVaultEntrypoint) {
    return _getStorageV1().entrypoint;
  }

  function strategyExecutor(address hubEOLVault) external view returns (address) {
    return _getStorageV1().eols[hubEOLVault].strategyExecutor;
  }

  //=========== NOTE: MUTATIVE FUNCTIONS ===========//

  //=========== NOTE: MUTATIVE - ASSET FUNCTIONS ===========//

  function initializeAsset(address asset) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertNotPaused(address(this), msg.sig);
    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());
    _assertAssetNotInitialized($, asset);

    $.assets[asset].initialized = true;
    emit AssetInitialized(asset);

    // NOTE: we halt deposit by default.
    $.globalAccessControlManager.pause(address(this), MitosisVault.deposit.selector, keccak256(abi.encode(asset)));
    $.globalAccessControlManager.pause(
      address(this), MitosisVault.depositWithOptIn.selector, keccak256(abi.encode(asset))
    );
  }

  function deposit(address asset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertNotPaused(address(this), msg.sig, keccak256(abi.encode(asset)));

    _deposit($, asset, to, amount);

    $.entrypoint.deposit(asset, to, amount);
    emit Deposited(asset, to, amount);
  }

  function depositWithOptIn(address asset, address to, address hubEOLVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertNotPaused(address(this), msg.sig, keccak256(abi.encode(asset)));

    _deposit($, asset, to, amount);

    _assertEOLInitialized($, hubEOLVault);
    require(asset == $.eols[hubEOLVault].asset, IMitosisVault__InvalidEOLVault(hubEOLVault, asset));

    $.entrypoint.depositWithOptIn(asset, to, hubEOLVault, amount);
    emit DepositedWithOptIn(asset, to, hubEOLVault, amount);
  }

  function redeem(address asset, address to, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertNotPaused(address(this), msg.sig, keccak256(abi.encode(asset)));
    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());
    _assertAssetInitialized($, asset);

    IERC20(asset).safeTransfer(to, amount);

    emit Redeemed(asset, to, amount);
  }

  //=========== NOTE: MUTATIVE - EOL FUNCTIONS ===========//

  function initializeEOL(address hubEOLVault, address asset) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertNotPaused(address(this), msg.sig);
    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());
    _assertEOLNotInitialized($, hubEOLVault);
    _assertAssetInitialized($, asset);

    $.eols[hubEOLVault].initialized = true;
    $.eols[hubEOLVault].asset = asset;

    emit EOLInitialized(hubEOLVault, asset);
  }

  function allocateEOL(address hubEOLVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertNotPaused(address(this), msg.sig, keccak256(abi.encode(hubEOLVault)));
    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());
    _assertEOLInitialized($, hubEOLVault);

    EOLInfo storage eolInfo = $.eols[hubEOLVault];

    eolInfo.availableEOL += amount;

    emit EOLAllocated(hubEOLVault, amount);
  }

  function deallocateEOL(address hubEOLVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertNotPaused(address(this), msg.sig, keccak256(abi.encode(hubEOLVault)));
    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());
    _assertEOLInitialized($, hubEOLVault);

    EOLInfo storage eolInfo = $.eols[hubEOLVault];

    eolInfo.availableEOL -= amount;
    $.entrypoint.deallocateEOL(hubEOLVault, amount);

    emit EOLDeallocated(hubEOLVault, amount);
  }

  function fetchEOL(address hubEOLVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertNotPaused(address(this), msg.sig, keccak256(abi.encode(hubEOLVault)));
    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());
    _assertEOLInitialized($, hubEOLVault);

    EOLInfo storage eolInfo = $.eols[hubEOLVault];

    eolInfo.availableEOL -= amount;
    IERC20(eolInfo.asset).safeTransfer(eolInfo.strategyExecutor, amount);

    emit EOLFetched(hubEOLVault, amount);
  }

  function returnEOL(address hubEOLVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertNotPaused(address(this), msg.sig, keccak256(abi.encode(hubEOLVault)));
    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());
    _assertEOLInitialized($, hubEOLVault);

    EOLInfo storage eolInfo = $.eols[hubEOLVault];

    IERC20(eolInfo.asset).safeTransferFrom(eolInfo.strategyExecutor, address(this), amount);
    eolInfo.availableEOL += amount;

    emit EOLReturned(hubEOLVault, amount);
  }

  function settleYield(address hubEOLVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertNotPaused(address(this), msg.sig, keccak256(abi.encode(hubEOLVault)));
    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());
    _assertEOLInitialized($, hubEOLVault);

    $.entrypoint.settleYield(hubEOLVault, amount);

    emit YieldSettled(hubEOLVault, amount);
  }

  function settleLoss(address hubEOLVault, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertNotPaused(address(this), msg.sig, keccak256(abi.encode(hubEOLVault)));
    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());
    _assertEOLInitialized($, hubEOLVault);

    $.entrypoint.settleLoss(hubEOLVault, amount);

    emit LossSettled(hubEOLVault, amount);
  }

  function settleExtraRewards(address hubEOLVault, address reward, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertNotPaused(address(this), msg.sig, keccak256(abi.encode(hubEOLVault)));
    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());
    _assertEOLInitialized($, hubEOLVault);
    _assertAssetInitialized($, reward);
    require(reward != $.eols[hubEOLVault].asset, StdError.InvalidAddress('reward'));

    IERC20(reward).safeTransferFrom(_msgSender(), address(this), amount);
    $.entrypoint.settleExtraRewards(hubEOLVault, reward, amount);

    emit ExtraRewardsSettled(hubEOLVault, reward, amount);
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function setEntrypoint(IMitosisVaultEntrypoint entrypoint_) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());

    if (address($.entrypoint) != address(0)) {
      $.globalAccessControlManager.revoke(address(this), _mitosisVaultEntrypointRoles(), address(entrypoint_));
    }

    $.globalAccessControlManager.grant(address(this), _mitosisVaultEntrypointRoles(), address(entrypoint_));

    $.entrypoint = entrypoint_;

    emit EntrypointSet(address(entrypoint_));
  }

  function setStrategyExecutor(address hubEOLVault, address strategyExecutor_) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());

    EOLInfo storage eolInfo = $.eols[hubEOLVault];

    _assertEOLInitialized($, hubEOLVault);

    if (eolInfo.strategyExecutor != address(0)) {
      // NOTE: no way to check if every extra rewards are settled.
      bool drained = IStrategyExecutor(eolInfo.strategyExecutor).totalBalance() == 0
        && IStrategyExecutor(eolInfo.strategyExecutor).lastSettledBalance() == 0;
      require(drained, IMitosisVault__StrategyExecutorNotDrained(hubEOLVault, eolInfo.strategyExecutor));

      $.globalAccessControlManager.revoke(address(this), _strategyExecutorRoles(), eolInfo.strategyExecutor);
    }

    require(
      hubEOLVault == IStrategyExecutor(strategyExecutor_).hubEOLVault(),
      StdError.InvalidId('strategyExecutor.hubEOLVault')
    );
    require(
      address(this) == address(IStrategyExecutor(strategyExecutor_).vault()),
      StdError.InvalidAddress('strategyExecutor.vault')
    );
    require(
      eolInfo.asset == address(IStrategyExecutor(strategyExecutor_).asset()),
      StdError.InvalidAddress('strategyExecutor.asset')
    );

    $.globalAccessControlManager.grant(address(this), _strategyExecutorRoles(), strategyExecutor_);

    eolInfo.strategyExecutor = strategyExecutor_;
    emit StrategyExecutorSet(hubEOLVault, strategyExecutor_);
  }

  function haltAssetDeposit(address asset) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());
    _assertAssetInitialized($, asset);

    $.globalAccessControlManager.pause(address(this), MitosisVault.deposit.selector, keccak256(abi.encode(asset)));
  }

  function haltDepositWithOptIn(address asset) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());
    _assertAssetInitialized($, asset);

    $.globalAccessControlManager.pause(
      address(this), MitosisVault.depositWithOptIn.selector, keccak256(abi.encode(asset))
    );
  }

  function resumeAssetDeposit(address asset) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());
    _assertAssetInitialized($, asset);

    $.globalAccessControlManager.unpause(address(this), MitosisVault.deposit.selector);
  }

  function resumeAssetDepositWithOptIn(address asset) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());
    _assertAssetInitialized($, asset);

    $.globalAccessControlManager.unpause(address(this), MitosisVault.depositWithOptIn.selector);
  }

  function haltFetchEOL(address hubEOLVault) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());
    _assertEOLInitialized($, hubEOLVault);

    $.globalAccessControlManager.pause(
      address(this), MitosisVault.fetchEOL.selector, keccak256(abi.encode(hubEOLVault))
    );
  }

  function resumeFetchEOL(address hubEOLVault) external {
    StorageV1 storage $ = _getStorageV1();

    $.globalAccessControlManager.assertHasRole(address(this), msg.sig, _msgSender());
    _assertEOLInitialized($, hubEOLVault);

    $.globalAccessControlManager.unpause(address(this), MitosisVault.fetchEOL.selector);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _mitosisVaultEntrypointRoles() internal pure returns (bytes4[] memory sigs) {
    sigs = new bytes4[](4);
    sigs[0] = MitosisVault.initializeAsset.selector;
    sigs[1] = MitosisVault.initializeEOL.selector;
    sigs[2] = MitosisVault.redeem.selector;
    sigs[3] = MitosisVault.allocateEOL.selector;
  }

  function _strategyExecutorRoles() internal pure returns (bytes4[] memory sigs) {
    sigs = new bytes4[](6);
    sigs[0] = MitosisVault.deallocateEOL.selector;
    sigs[1] = MitosisVault.fetchEOL.selector;
    sigs[2] = MitosisVault.returnEOL.selector;
    sigs[3] = MitosisVault.settleYield.selector;
    sigs[4] = MitosisVault.settleLoss.selector;
    sigs[5] = MitosisVault.settleExtraRewards.selector;
  }

  function _assertAssetInitialized(StorageV1 storage $, address asset) internal view {
    require(_isAssetInitialized($, asset), IMitosisVault__AssetNotInitialized(asset));
  }

  function _assertAssetNotInitialized(StorageV1 storage $, address asset) internal view {
    require(!_isAssetInitialized($, asset), IMitosisVault__AssetAlreadyInitialized(asset));
  }

  function _assertEOLInitialized(StorageV1 storage $, address hubEOLVault) internal view {
    require(_isEOLInitialized($, hubEOLVault), IMitosisVault__EOLNotInitialized(hubEOLVault));
  }

  function _assertEOLNotInitialized(StorageV1 storage $, address hubEOLVault) internal view {
    require(!_isEOLInitialized($, hubEOLVault), IMitosisVault__EOLAlreadyInitialized(hubEOLVault));
  }

  function _isAssetInitialized(StorageV1 storage $, address asset) internal view returns (bool) {
    return $.assets[asset].initialized;
  }

  function _isEOLInitialized(StorageV1 storage $, address hubEOLVault) internal view returns (bool) {
    return $.eols[hubEOLVault].initialized;
  }

  function _deposit(StorageV1 storage $, address asset, address to, uint256 amount) internal {
    _assertAssetInitialized($, asset);

    require(to != address(0), StdError.ZeroAddress('to'));
    require(amount != 0, StdError.ZeroAmount());

    IERC20(asset).safeTransferFrom(_msgSender(), address(this), amount);
  }
}
