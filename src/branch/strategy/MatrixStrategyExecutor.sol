// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20, IERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Address } from '@oz-v5/utils/Address.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { MatrixStrategyExecutorStorageV1 } from './MatrixStrategyExecutorStorageV1.sol';
import { IMatrixStrategyExecutor } from '../../interfaces/branch/strategy/IMatrixStrategyExecutor.sol';
import { Pausable } from '../../lib/Pausable.sol';
import { StdError } from '../../lib/StdError.sol';
import { ITally } from '../../interfaces/branch/strategy/tally/ITally.sol';
import { IStrategyExecutor } from '../../interfaces/branch/strategy/IStrategyExecutor.sol';
import { IMitosisVault } from '../../interfaces/branch/IMitosisVault.sol';

contract MatrixStrategyExecutor is
  IStrategyExecutor,
  IMatrixStrategyExecutor,
  Pausable,
  Ownable2StepUpgradeable,
  MatrixStrategyExecutorStorageV1
{
  using SafeERC20 for IERC20;
  using Address for address;

  //=========== NOTE: IMMUTABLE VARIABLES ===========//

  IMitosisVault internal immutable _vault;
  IERC20 internal immutable _asset;
  address internal immutable _hubMatrixVault;

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor(IMitosisVault vault_, IERC20 asset_, address hubMatrixVault_) initializer {
    _vault = vault_;
    _asset = asset_;
    _hubMatrixVault = hubMatrixVault_;
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

  function vault() external view returns (IMitosisVault) {
    return _vault;
  }

  function asset() external view returns (IERC20) {
    return _asset;
  }

  function hubMatrixVault() external view returns (address) {
    return _hubMatrixVault;
  }

  function strategist() external view returns (address) {
    return _getStorageV1().strategist;
  }

  function executor() external view returns (address) {
    return _getStorageV1().executor;
  }

  function emergencyManager() external view returns (address) {
    return _getStorageV1().emergencyManager;
  }

  function tally() external view returns (ITally) {
    return _getStorageV1().tally;
  }

  function totalBalance() external view returns (uint256) {
    return _totalBalance(_getStorageV1());
  }

  function storedTotalBalance() external view returns (uint256) {
    return _getStorageV1().storedTotalBalance;
  }

  //=========== NOTE: STRATEGIST FUNCTIONS ===========//

  function deallocateLiquidity(uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
    _assertOnlyStrategist($);

    _vault.deallocateMatrixLiquidity(_hubMatrixVault, amount);
  }

  function fetchLiquidity(uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
    _assertOnlyStrategist($);

    _vault.fetchMatrixLiquidity(_hubMatrixVault, amount);
    $.storedTotalBalance += amount;
  }

  function returnLiquidity(uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
    _assertOnlyStrategist($);

    _asset.approve(address(_vault), amount);
    _vault.returnMatrixLiquidity(_hubMatrixVault, amount);
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
      _vault.settleMatrixYield(_hubMatrixVault, totalBalance_ - storedTotalBalance_);
    } else {
      _vault.settleMatrixLoss(_hubMatrixVault, storedTotalBalance_ - totalBalance_);
    }
  }

  function settleExtraRewards(address reward, uint256 amount) external {
    StorageV1 storage $ = _getStorageV1();

    _assertNotPaused();
    _assertOnlyStrategist($);
    require(reward != address(_asset), StdError.InvalidAddress('reward'));

    IERC20(reward).approve(address(_vault), amount);
    _vault.settleMatrixExtraRewards(_hubMatrixVault, reward, amount);
  }

  //=========== NOTE: EXECUTOR FUNCTIONS ===========//

  function execute(address target, bytes calldata data, uint256 value) external returns (bytes memory result) {
    StorageV1 storage $ = _getStorageV1();
    _assertOnlyExecutor($);
    _assertOnlyTallyRegisteredProtocol($, target);

    result = target.functionCallWithValue(data, value);
  }

  function execute(address[] calldata targets, bytes[] calldata data, uint256[] calldata values)
    external
    returns (bytes[] memory results)
  {
    StorageV1 storage $ = _getStorageV1();
    _assertOnlyExecutor($);
    _assertOnlyTallyRegisteredProtocol($, targets);

    uint256 targetsLength = targets.length;
    results = new bytes[](targetsLength);
    for (uint256 i; i < targetsLength; ++i) {
      results[i] = targets[i].functionCallWithValue(data[i], values[i]);
    }
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function setTally(address implementation) external onlyOwner {
    require(implementation.code.length > 0, StdError.InvalidAddress('implementation'));

    StorageV1 storage $ = _getStorageV1();
    require(
      address($.tally) == address(0) || _tallyTotalBalance($) == 0,
      IMatrixStrategyExecutor.IMatrixStrategyExecutor__TallyTotalBalanceNotZero(implementation)
    );

    $.tally = ITally(implementation);
    emit TallySet(implementation);
  }

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

  function setExecutor(address executor_) external onlyOwner {
    require(executor_ != address(0), StdError.InvalidAddress('executor'));
    _getStorageV1().executor = executor_;
    emit ExecutorSet(executor_);
  }

  function unsetStrategist() external onlyOwner {
    _getStorageV1().strategist = address(0);
    emit StrategistSet(address(0));
  }

  function unsetExecutor() external onlyOwner {
    _getStorageV1().executor = address(0);
    emit ExecutorSet(address(0));
  }

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
    require(strategist_ != address(0), IMatrixStrategyExecutor.IMatrixStrategyExecutor__StrategistNotSet());
    require(_msgSender() == strategist_, StdError.Unauthorized());
  }

  function _assertOnlyExecutor(StorageV1 storage $) internal view {
    address executor_ = $.executor;
    require(executor_ != address(0), IMatrixStrategyExecutor.IMatrixStrategyExecutor__ExecutorNotSet());
    require(_msgSender() == executor_, StdError.Unauthorized());
  }

  function _assertOnlyTallyRegisteredProtocol(StorageV1 storage $, address target) internal view {
    require($.tally.protocolAddress() == target, IMatrixStrategyExecutor__TallyNotSet(target));
  }

  function _assertOnlyTallyRegisteredProtocol(StorageV1 storage $, address[] memory targets) internal view {
    address expected = $.tally.protocolAddress();
    for (uint256 i = 0; i < targets.length; i++) {
      address target = targets[i];
      require(expected == target, IMatrixStrategyExecutor__TallyNotSet(target));
    }
  }

  function _tallyTotalBalance(StorageV1 storage $) internal view returns (uint256) {
    bytes memory temp;
    return $.tally.totalBalance(temp);
  }

  function _totalBalance(StorageV1 storage $) internal view returns (uint256) {
    return _asset.balanceOf(address(this)) + _tallyTotalBalance($);
  }
}
