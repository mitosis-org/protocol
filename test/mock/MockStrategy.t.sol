// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';

import { IStrategy } from '../../src/interfaces/branch/strategy/IStrategy.sol';

contract MockStrategy is IStrategy {
  address _asset;
  uint256 _balance;

  constructor(address asset_) {
    _asset = asset_;
  }

  function setBalance(uint256 balance) external {
    _balance = balance;
  }

  function asset() external view returns (IERC20) {
    return IERC20(_asset);
  }

  function self() external view returns (address) {
    return address(this);
  }

  function strategyName() external pure returns (string memory) {
    return 'MockStrategy';
  }

  function isDepositAsync() external pure returns (bool) {
    return false;
  }

  function isWithdrawAsync() external pure returns (bool) {
    return false;
  }

  function totalBalance(bytes memory) external view returns (uint256 totalBalance_) {
    return _balance;
  }

  function withdrawableBalance(bytes memory) external view returns (uint256 availableBalance_) {
    return _balance;
  }

  function pendingDepositBalance(bytes memory) external pure returns (uint256 pendingDepositBalance_) {
    return 0;
  }

  function pendingWithdrawBalance(bytes memory) external pure returns (uint256 pendingWithdrawBalance_) {
    return 0;
  }

  function previewDeposit(uint256 amount, bytes memory) external pure returns (uint256 deposited) {
    return amount;
  }

  function previewWithdraw(uint256 amount, bytes memory) external pure returns (uint256 withdrawn) {
    return amount;
  }

  function requestDeposit(uint256, bytes memory) external pure returns (bytes memory ret) {
    return '';
  }

  function deposit(uint256 amount, bytes memory) external pure returns (uint256 deposited) {
    return amount;
  }

  function requestWithdraw(uint256, bytes memory) external pure returns (bytes memory ret) {
    return '';
  }

  function withdraw(uint256 amount, bytes memory) external pure returns (uint256 withdrawn) {
    return amount;
  }
}
