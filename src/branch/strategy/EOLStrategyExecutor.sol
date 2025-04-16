// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20, IERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Address } from '@oz-v5/utils/Address.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { EOLStrategyExecutorStorageV1 } from '../../branch/strategy/EOLStrategyExecutorStorageV1.sol';
import { StdStrategy } from '../../branch/strategy/strategies/StdStrategy.sol';
import { IMitosisVault } from '../../interfaces/branch/IMitosisVault.sol';
import { IEOLStrategyExecutor } from '../../interfaces/branch/strategy/IEOLStrategyExecutor.sol';
import { IStrategy, IStrategyDependency } from '../../interfaces/branch/strategy/IStrategy.sol';
import { Pausable } from '../../lib/Pausable.sol';
import { StdError } from '../../lib/StdError.sol';

contract EOLStrategyExecutor is
  IStrategyDependency,
  IEOLStrategyExecutor,
  Pausable,
  Ownable2StepUpgradeable,
  EOLStrategyExecutorStorageV1
{
  using SafeERC20 for IERC20;
  using Address for address;

  //=========== NOTE: IMMUTABLE VARIABLES ===========//

  IMitosisVault internal immutable _vault;
  IERC20 internal immutable _asset;
  address internal immutable _hubEOLVault;

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor(IMitosisVault vault_, IERC20 asset_, address hubEOLVault_) initializer {
    _vault = vault_;
    _asset = asset_;
    _hubEOLVault = hubEOLVault_;
  }

  fallback() external payable {
    revert StdError.Unauthorized();
  }

  receive() external payable {
    revert StdError.Unauthorized();
  }

  function initialize(address owner_, address emergencyManager_) public initializer {
    __Pausable_init();
    __Ownable2Step_init();
    _transferOwnership(owner_);

    StorageV1 storage $ = _getStorageV1();

    $.emergencyManager = emergencyManager_;
  }

  //=========== NOTE: VIEW FUNCTIONS ===========//

  function vault() public view returns (IMitosisVault) {
    return _vault;
  }

  function asset() public view override(IEOLStrategyExecutor, IStrategyDependency) returns (IERC20) {
    return _asset;
  }

  function hubEOLVault() public view returns (address) {
    return _hubEOLVault;
  }

  function strategist() external view returns (address) {
    return _getStorageV1().strategist;
  }

  function emergencyManager() external view returns (address) {
    return _getStorageV1().emergencyManager;
  }

  function getStrategy(uint256 strategyId) external view override returns (Strategy memory) {
    return _getStrategy(_getStorageV1(), strategyId);
  }

  function getStrategy(address implementation) external view override returns (Strategy memory) {
    return _getStrategy(_getStorageV1(), implementation);
  }

  /**
   * @dev you must need to careful when using this function. If the enabled list is too long, it may cause out of gas
   */
  function getEnabledStrategyIds() external view override returns (uint256[] memory) {
    return _getStorageV1().strategies.enabled;
  }

  function isStrategyEnabled(uint256 strategyId) external view returns (bool) {
    return _isStrategyEnabled(_getStorageV1(), strategyId);
  }

  function isStrategyEnabled(address implementation) external view returns (bool) {
    StorageV1 storage $ = _getStorageV1();
    return _isStrategyEnabled($, $.strategies.idxByImpl[implementation]);
  }

  function totalBalance() external view returns (uint256) {
    return _totalBalance(_getStorageV1());
  }

  function storedTotalBalance() external view returns (uint256) {
    return _getStorageV1().storedTotalBalance;
  }

  //=========== NOTE: STRATEGIST FUNCTIONS ===========//

  function deallocateEOL(uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
    _assertOnlyStrategist($);

    _vault.deallocateEOL(_hubEOLVault, amount);
  }

  function fetchEOL(uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
    _assertOnlyStrategist($);

    _vault.fetchEOL(_hubEOLVault, amount);
    $.storedTotalBalance += amount;
  }

  function returnEOL(uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
    _assertOnlyStrategist($);

    _asset.approve(address(_vault), amount);
    _vault.returnEOL(_hubEOLVault, amount);
    $.storedTotalBalance -= amount;
  }

  function settle() external {
    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
    _assertOnlyStrategist($);

    uint256 totalBalance_ = _totalBalance($);
    uint256 storedTotalBalance_ = $.storedTotalBalance;

    $.storedTotalBalance = totalBalance_;

    if (totalBalance_ >= storedTotalBalance_) {
      _vault.settleYield(_hubEOLVault, totalBalance_ - storedTotalBalance_);
    } else {
      _vault.settleLoss(_hubEOLVault, storedTotalBalance_ - totalBalance_);
    }
  }

  function settleExtraRewards(address reward, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
    _assertOnlyStrategist($);
    require(reward != address(_asset), StdError.InvalidAddress('reward'));

    IERC20(reward).approve(address(_vault), amount);
    _vault.settleExtraRewards(_hubEOLVault, reward, amount);
  }

  /**
   * @notice do not execute a calls that indicates a transfer of funds
   * - It would violate the liquidity tracking mechanism of strategy executor
   *
   * @dev only strategist can call this function
   */
  function execute(IEOLStrategyExecutor.Call[] calldata calls) external {
    // TODO(thai): check that total balance is almost the same before and after the execution.

    // TODO(thai): for now, strategist can move funds to defi positions not tracked by `totalBalance`.
    //   It may incur a loss because `totalBalance` becomes less.
    //   We should add mechanism to prevent this.

    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
    _assertOnlyStrategist($);

    for (uint256 i = 0; i < calls.length; i++) {
      uint256 strategyId = calls[i].strategyId;
      Strategy memory strategy = _getStrategy($, strategyId);
      require(strategy.enabled, IEOLStrategyExecutor__StrategyNotEnabled(strategyId));

      for (uint256 j = 0; j < calls[i].callData.length; j++) {
        strategy.implementation.functionDelegateCall(calls[i].callData[j]);
      }
    }
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  // MANAGES STRATEGIES

  function addStrategy(uint256 priority, address implementation, bytes calldata context)
    external
    onlyOwner
    returns (uint256)
  {
    require(implementation.code.length > 0, StdError.InvalidAddress('implementation'));

    StorageV1 storage $ = _getStorageV1();
    {
      uint256 id = $.strategies.idxByImpl[implementation];
      require(
        implementation != $.strategies.reg[id].implementation,
        IEOLStrategyExecutor__StrategyAlreadySet(implementation, id)
      );
    }

    uint256 nextId = $.strategies.len;

    $.strategies.reg[nextId] = Strategy({
      priority: priority,
      implementation: implementation,
      enabled: false, // disabled by default
      context: context
    });
    $.strategies.idxByImpl[implementation] = nextId;
    $.strategies.len++;

    emit StrategyAdded(nextId, implementation, priority);

    return nextId;
  }

  function enableStrategy(uint256 strategyId) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    // toggle
    Strategy storage strategy = _getStrategy($, strategyId);
    require(!strategy.enabled, IEOLStrategyExecutor__StrategyAlreadyEnabled(strategyId));
    strategy.enabled = true;

    // add to enabled list
    $.strategies.enabled.push(strategyId);

    emit StrategyEnabled(strategyId);
  }

  function disableStrategy(uint256 strategyId) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    // toggle
    Strategy storage strategy = _getStrategy($, strategyId);
    require(strategy.enabled, IEOLStrategyExecutor__StrategyNotEnabled(strategyId));
    strategy.enabled = false;

    // remove from enabled list
    uint256[] storage enabled = $.strategies.enabled;
    for (uint256 i = 0; i < enabled.length; i++) {
      if (enabled[i] == strategyId) {
        if (enabled.length > 1) enabled[i] = enabled[enabled.length - 1];
        enabled.pop();
        break;
      }
    }

    emit StrategyDisabled(strategyId);
  }

  // MANAGES ROLES

  function setEmergencyManager(address emergencyManager_) external onlyOwner {
    require(emergencyManager_ != address(0), StdError.InvalidAddress('emergencyManager'));
    _getStorageV1().emergencyManager = emergencyManager_;
    emit EmergencyManagerSet(emergencyManager_);
  }

  function setStrategist(address strategist_) external onlyOwner {
    require(strategist_ != address(0), StdError.InvalidAddress('strategist'));
    _getStorageV1().strategist = strategist_;
    emit StrategistSet(strategist_);
  }

  function unsetStrategist() external onlyOwner {
    _getStorageV1().strategist = address(0);
    emit StrategistSet(address(0));
  }

  // MANAGES PAUSABILITY

  function pause() external {
    StorageV1 storage $ = _getStorageV1();
    require(_msgSender() == owner() || _msgSender() == $.emergencyManager, StdError.Unauthorized());
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _assertOnlyStrategist(StorageV1 storage $) internal view {
    address strategist_ = $.strategist;
    require(strategist_ != address(0), IEOLStrategyExecutor__StrategistNotSet());
    require(_msgSender() == strategist_, StdError.Unauthorized());
  }

  function _getStrategy(StorageV1 storage $, uint256 strategyId) internal view returns (Strategy storage strategy) {
    return $.strategies.reg[strategyId];
  }

  function _getStrategy(StorageV1 storage $, address implementation) internal view returns (Strategy storage strategy) {
    return $.strategies.reg[$.strategies.idxByImpl[implementation]];
  }

  function _isStrategyEnabled(StorageV1 storage $, uint256 strategyId) internal view returns (bool enabled) {
    return $.strategies.len > strategyId && _getStrategy($, strategyId).enabled;
  }

  function _totalBalance(StorageV1 storage $, uint256 strategyId) internal view returns (uint256) {
    Strategy memory strategy = _getStrategy($, strategyId);

    // TODO(thai): is it okay to use `strategy.context` for `pendingWithdrawBalance()`?
    return IStrategy(strategy.implementation).totalBalance(strategy.context)
      + IStrategy(strategy.implementation).pendingWithdrawBalance(strategy.context);
  }

  function _totalBalance(StorageV1 storage $) internal view returns (uint256) {
    uint256 total = _asset.balanceOf(address(this));

    for (uint256 i = 0; i < $.strategies.len; i++) {
      total += _totalBalance($, i);
    }

    return total;
  }
}
