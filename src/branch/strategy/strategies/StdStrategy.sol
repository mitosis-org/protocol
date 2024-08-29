// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Context } from '@oz-v5/utils/Context.sol';
import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';

import { IStrategy, IStrategyDependency } from '../../../interfaces/branch/strategy/IStrategy.sol';
import { IStrategyExecutor } from '../../../interfaces/branch/strategy/IStrategyExecutor.sol';
import { StdError } from '../../../lib/StdError.sol';
import { StdStrategyStorageV1 } from '../../../branch/strategy/storage/StdStrategyStorageV1.sol';

abstract contract StdStrategy is IStrategy, Context, StdStrategyStorageV1 {
  using SafeERC20 for IERC20;

  event DepositRequested(bytes ret);
  event WithdrawRequested(bytes ret);

  error StdStrategy__OnlyDelegateCall();

  address internal immutable _self; // cannot be queried when this contract is used as a proxy

  constructor() {
    _self = address(this);
  }

  modifier onlyDelegateCall() {
    if (address(this) == _self) revert StdStrategy__OnlyDelegateCall();

    _;
  }

  //================= NOTE: VIEW FUNCTIONS =================//

  function asset() external view override onlyDelegateCall returns (IERC20) {
    return _asset();
  }

  function strategyName() public pure virtual override(IStrategy, StdStrategyStorageV1) returns (string memory);

  function self() external view override returns (address) {
    return _self;
  }

  function isDepositAsync() external pure override returns (bool) {
    return _isDepositAsync();
  }

  function isWithdrawAsync() external pure override returns (bool) {
    return _isWithdrawAsync();
  }

  function totalBalance(bytes memory context) external view returns (uint256 totalBalance_) {
    return _totalBalance(context);
  }

  function withdrawableBalance(bytes memory context) external view returns (uint256 withdrawableBalance_) {
    return _withdrawableBalance(context);
  }

  function pendingDepositBalance(bytes memory context) public view virtual returns (uint256 pendingDepositBalance_) {
    return _pendingDepositBalance(context);
  }

  function pendingWithdrawBalance(bytes memory context) public view virtual returns (uint256 pendingWithdrawBalance_) {
    return _pendingWithdrawBalance(context);
  }

  //================= NOTE: SIMULATION FUNCTIONS =================//

  function previewDeposit(uint256 amount, bytes memory context) external view returns (uint256 deposited) {
    return _previewDeposit(amount, context);
  }

  function previewWithdraw(uint256 amount, bytes memory context) external view returns (uint256 withdrawn) {
    return _previewWithdraw(amount, context);
  }

  //================= NOTE: STRATEGY FUNCTIONS =================//

  function requestDeposit(uint256 amount, bytes memory context) external onlyDelegateCall returns (bytes memory ret) {
    ret = _requestDeposit(amount, context);

    emit DepositRequested(ret);

    return ret;
  }

  function deposit(uint256 amount, bytes memory context) external onlyDelegateCall returns (uint256 deposited) {
    _deposit(amount, context);

    emit Deposit(_self, amount, context);

    return amount;
  }

  function requestWithdraw(uint256 amount, bytes memory context) external onlyDelegateCall returns (bytes memory ret) {
    ret = _requestWithdraw(amount, context);

    emit WithdrawRequested(ret);

    return ret;
  }

  function withdraw(uint256 amount, bytes memory context) external onlyDelegateCall returns (uint256 withdrawn) {
    _withdraw(amount, context);

    emit Withdraw(_self, amount, context);

    return amount;
  }

  //================= NOTE: INTERNAL VIEW FUNCTIONS =================//

  function _asset() internal view virtual returns (IERC20) {
    return IStrategyDependency(this).asset();
  }

  /**
   * @dev must override this if the strategy is supporting async deposit
   */
  function _isDepositAsync() internal pure virtual returns (bool) {
    return false; // as default
  }

  /**
   * @dev must override this if the strategy is supporting async withdraw
   */
  function _isWithdrawAsync() internal pure virtual returns (bool) {
    return false; // as default
  }

  /**
   * @dev must implement this
   */
  function _totalBalance(bytes memory context) internal view virtual returns (uint256 totalBalance_);

  /**
   * @dev override this if the strategy is supporting async withdraw
   */
  function _withdrawableBalance(bytes memory context) internal view virtual returns (uint256 withdrawableBalance_) {
    return _totalBalance(context); // as default
  }

  /**
   * @dev override this if the strategy is supporting async deposit
   */
  function _pendingDepositBalance(bytes memory) internal view virtual returns (uint256 pendingDepositBalance_) {
    return 0; // as default
  }

  /**
   * @dev override this if the strategy is supporting async withdraw
   */
  function _pendingWithdrawBalance(bytes memory) internal view virtual returns (uint256 pendingWithdrawBalance_) {
    return 0; // as default
  }

  //================= NOTE: INTERNAL SIMULATION FUNCTIONS =================//

  function _previewDeposit(uint256 amount, bytes memory) internal view virtual returns (uint256) {
    return _isDepositAsync() ? 0 : amount;
  }

  function _previewWithdraw(uint256 amount, bytes memory) internal view virtual returns (uint256) {
    return _isWithdrawAsync() ? 0 : amount;
  }

  //================= NOTE: INTERNAL EXEC FUNCTIONS =================//

  function _requestDeposit(uint256, bytes memory) internal virtual returns (bytes memory) {
    revert StdError.NotImplemented();
  }

  function _requestWithdraw(uint256, bytes memory) internal virtual returns (bytes memory) {
    revert StdError.NotImplemented();
  }

  /**
   * @dev must implement this function without any interaction with the vault - `deposit` function wil handle it
   */
  function _deposit(uint256 amount, bytes memory context) internal virtual;

  /**
   * @dev must implement this function without any asset transfer - `withdraw` function will handle it
   */
  function _withdraw(uint256 amount, bytes memory context) internal virtual;
}
