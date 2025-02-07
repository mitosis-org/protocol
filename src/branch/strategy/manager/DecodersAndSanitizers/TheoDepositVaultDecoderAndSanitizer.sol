// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import { BaseDecoderAndSanitizer } from './BaseDecoderAndSanitizer.sol';

contract TheoDepositVaultDecoderAndSanitizer is BaseDecoderAndSanitizer {
  constructor(address strategyExecutor_) BaseDecoderAndSanitizer(strategyExecutor_) { }

  function depositETH() external pure returns (bytes memory addresssesFound) {
    return addresssesFound;
  }

  function deposit(uint256) external pure returns (bytes memory addresssesFound) {
    return addresssesFound;
  }

  function depositFor(uint256, address creditor) external pure returns (bytes memory addresssesFound) {
    addresssesFound = abi.encodePacked(creditor);
  }

  function depositETHFor(address creditor) external pure returns (bytes memory addresssesFound) {
    addresssesFound = abi.encodePacked(creditor);
  }

  function privateDepositETH(bytes32[] memory) external pure returns (bytes memory addresssesFound) {
    return addresssesFound;
  }

  function privateDeposit(uint256, bytes32[] memory) external pure returns (bytes memory addresssesFound) {
    return addresssesFound;
  }

  function withdrawInstantly(uint256) external pure returns (bytes memory addresssesFound) {
    return addresssesFound;
  }

  function initiateWithdraw(uint256) external pure returns (bytes memory addresssesFound) {
    return addresssesFound;
  }

  function completeWithdraw() external pure returns (bytes memory addresssesFound) {
    return addresssesFound;
  }

  function redeem(uint256) external pure returns (bytes memory addresssesFound) {
    return addresssesFound;
  }

  function maxRedeem() external pure returns (bytes memory addresssesFound) {
    return addresssesFound;
  }
}
