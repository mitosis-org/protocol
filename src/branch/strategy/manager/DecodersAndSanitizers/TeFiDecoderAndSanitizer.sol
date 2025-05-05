// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { BaseDecoderAndSanitizer } from './BaseDecoderAndSanitizer.sol';

contract TeFiDecoderAndSanitizer is BaseDecoderAndSanitizer {
  function claim(address asset, uint256) external pure returns (bytes memory addressesFound) {
    addressesFound = abi.encodePacked(asset);
  }

  function withdraw(address asset, uint256) external pure returns (bytes memory addressesFound) {
    addressesFound = abi.encodePacked(asset);
  }

  function triggerLoss(uint256) external pure returns (bytes memory addressesFound) {
    return addressesFound;
  }
}
